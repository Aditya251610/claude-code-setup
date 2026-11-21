import { expect, mock, test } from 'claude-code/testing'

const TASK = '/tmp/x/tasks/abc123.output'
const BG = `Command running in background with ID: abc123. Output is being written to: ${TASK}. You will be notified`

function engine(on: any) {
  const toasts: string[] = []
  const statuses: (string | undefined)[] = []
  on('ui.toast', (_: unknown, e: any) => { toasts.push(String(e.text)); return { value: undefined } })
  on('ui.status', (_: unknown, e: any) => { statuses.push(e.text); return { value: undefined } })
  const clock = mock.clock(on, { now: 1_000_000 })
  return { toasts, statuses, clock }
}

test('a short foreground command shows nothing', async ($, on) => {
  const { toasts } = engine(on)
  on('tool.call', () => ({ result: {}, text: 'fine' }))
  await $.tool.call({ tool: 'Bash', command: 'ls' })
  expect(toasts.length).toBe(0)
})

test('a failing short command is still quiet', async ($, on) => {
  const { toasts } = engine(on)
  on('tool.call', () => ({ result: {}, text: 'boom', isError: true }))
  await $.tool.call({ tool: 'Bash', command: 'false' })
  expect(toasts.length).toBe(0)
})

test('a long foreground command toasts once past the mark and again with its result', async ($, on) => {
  const { toasts, statuses, clock } = engine(on)
  on('tool.call', async () => {
    await clock.advance(12_000)
    return { result: {}, text: 'compiling\nlinking\nall done' }
  })
  await $.tool.call({ tool: 'Bash', command: 'make all' })
  expect(toasts.length).toBe(2)
  expect(toasts[0]).toContain('running over 10s')
  expect(toasts[1]).toContain('✔ make all')
  expect(toasts[1]).toContain('all done')
  expect(statuses.some((s) => s && s.includes('make all'))).toBe(true)
})

test('a background command: toast, live status line, closing toast with the exit code', async ($, on) => {
  const { toasts, statuses, clock } = engine(on)
  let output = 'booting\nlistening on :3000'
  on('tool.call', () => ({ result: {}, text: BG }))
  on('process.run', () => ({ value: { exitCode: 0, stdout: output, stderr: '' } }))

  await $.tool.call({ tool: 'Bash', command: 'npm run dev', run_in_background: true })
  expect(toasts[0]).toContain('⏵ npm run dev')

  await clock.advance(2_100)
  expect(statuses.some((s) => s && s.includes('listening on :3000'))).toBe(true)

  output = 'booting\nlistening on :3000\nshutting down\n\n[exited with code 0]'
  await clock.advance(2_100)
  const last = toasts[toasts.length - 1]
  expect(last).toContain('✔ npm run dev')
  expect(last).toContain('exit 0')
  expect(last).toContain('shutting down')
  expect(statuses[statuses.length - 1]).toBeUndefined()
})

test('a background command whose output file cannot be read stops being followed instead of sticking', async ($, on) => {
  const { toasts, statuses, clock } = engine(on)
  on('tool.call', () => ({ result: {}, text: BG }))
  on('process.run', () => ({ value: { exitCode: 1, stdout: '', stderr: 'tail: cannot open' } }))

  await $.tool.call({ tool: 'Bash', command: 'tail -f gone.log', run_in_background: true })
  await clock.advance(100)
  expect(statuses.some((s) => s && s.includes('tail -f gone.log'))).toBe(true)

  await clock.advance(7_000)
  expect(statuses[statuses.length - 1]).toBeUndefined()
  expect(toasts.length).toBe(1)
})
