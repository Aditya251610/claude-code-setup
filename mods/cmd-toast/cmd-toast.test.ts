import { expect, mock, test } from 'claude-code/testing'

const TASK = '/tmp/x/tasks/abc123.output'
const BG = `Command running in background with ID: abc123. Output is being written to: ${TASK}. You will be notified`
const BAND = {
  plugin: 'cmd-toast',
  component: 'AbovePrompt',
  props: { hasSurvey: false, isCollapsed: false, isWorking: true, maxRows: 12, bodyColumns: 100, scroll: { offset: 0, bodyRows: 12 }, view: {} },
} as const

// The mod reads an output file with the file API (stat, then a byte range), so tests mock those two.
function mockFile(on: any, read: () => string | undefined) {
  on('fs.stat', () => {
    const text = read()
    if (text === undefined) throw new Error('ENOENT')
    return { value: { kind: 'file', size: text.length, mtimeMs: 0, isLink: false } }
  })
  on('fs.read', (_: unknown, e: any) => {
    const text = read() ?? ''
    const start = e.offset ?? 0
    return { value: text.slice(start, e.length === undefined ? undefined : start + e.length) }
  })
}

function engine(on: any) {
  const toasts: string[] = []
  const statuses: unknown[] = []
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

test('a long foreground command: toast at the mark, a live card, a toast with its result, never the status line', async ($, on) => {
  const { toasts, statuses, clock } = engine(on)
  let ui: any
  on('tool.call', async () => {
    await clock.advance(12_000)
    ui = await $.ui.mount({ ...BAND, surface: 'terminal' })
    expect(await ui.find({ type: 'Text', text: /▶ make all  0:12/ })).toBeTruthy()
    await ui.unmount()
    return { result: {}, text: 'compiling\nlinking\nall done' }
  })
  await $.tool.call({ tool: 'Bash', command: 'make all' })
  expect(toasts.length).toBe(2)
  expect(toasts[0]).toContain('running over 10s')
  expect(toasts[1]).toContain('✔ make all')
  expect(toasts[1]).toContain('all done')
  expect(statuses.length).toBe(0)
})

test('a background command: live card, expand shows command and output, × hides only the card, exit toast', async ($, on) => {
  const { toasts, statuses, clock } = engine(on)
  let output = 'booting\nlistening on :3000'
  on('tool.call', () => ({ result: {}, text: BG }))
  mockFile(on, () => output)

  await $.tool.call({ tool: 'Bash', command: 'npm run dev', run_in_background: true })
  expect(toasts[0]).toContain('⏵ npm run dev')
  await clock.advance(2_100)

  const ui = await $.ui.mount({ ...BAND, surface: 'terminal' })
  expect(await ui.find({ type: 'Text', text: /▶ npm run dev/ })).toBeTruthy()
  expect(await ui.find({ type: 'Text', text: /listening on :3000/ })).toBeFalsy()

  await ui.press({ key: 'exp-1' })
  expect(await ui.find({ type: 'Text', text: /\$ npm run dev/ })).toBeTruthy()
  expect(await ui.find({ type: 'Text', text: /listening on :3000/ })).toBeTruthy()
  expect(await ui.find({ type: 'Text', text: /keeps running/ })).toBeTruthy()

  await ui.press({ key: 'x-1' })
  expect(await ui.find({ type: 'Text', text: /npm run dev/ })).toBeFalsy()

  output = 'booting\nshutting down\n\n[exited with code 0]'
  await clock.advance(2_100)
  const last = toasts[toasts.length - 1]
  expect(last).toContain('✔ npm run dev')
  expect(last).toContain('exit 0')
  expect(last).toContain('shutting down')
  expect(statuses.length).toBe(0)
  await ui.unmount()
})

test('a finished card goes away after a while; an unreadable output file stops being followed', async ($, on) => {
  const { toasts, clock } = engine(on)
  on('tool.call', () => ({ result: {}, text: BG }))
  mockFile(on, () => undefined)
  await $.tool.call({ tool: 'Bash', command: 'tail -f gone.log', run_in_background: true })
  await clock.advance(7_000)
  let ui = await $.ui.mount({ ...BAND, surface: 'terminal' })
  expect(await ui.find({ type: 'Text', text: /lost track/ })).toBeTruthy()
  await ui.unmount()
  await clock.advance(25_000)
  ui = await $.ui.mount({ ...BAND, surface: 'terminal' })
  expect(await ui.find({ type: 'Text', text: /tail -f gone\.log/ })).toBeFalsy()
  expect(toasts.length).toBe(1)
  await ui.unmount()
})

test('a command that throws after the mark leaves no card stuck on running', async ($, on) => {
  const { clock } = engine(on)
  on('tool.call', async () => {
    await clock.advance(12_000)
    throw new Error('tool crashed')
  })
  await $.tool.call({ tool: 'Bash', command: 'make broken' }).catch(() => undefined)
  const ui = await $.ui.mount({ ...BAND, surface: 'terminal' })
  expect(await ui.find({ type: 'Text', text: /▶ make broken/ })).toBeFalsy()
  expect(await ui.find({ type: 'Text', text: /✘ make broken/ })).toBeTruthy()
  await ui.unmount()
})

test('a lost card shows ? and not the failure mark', async ($, on) => {
  const { clock } = engine(on)
  on('tool.call', () => ({ result: {}, text: BG }))
  mockFile(on, () => undefined)
  await $.tool.call({ tool: 'Bash', command: 'tail -f gone.log', run_in_background: true })
  await clock.advance(7_000)
  const ui = await $.ui.mount({ ...BAND, surface: 'terminal' })
  expect(await ui.find({ type: 'Text', text: /\? tail -f gone\.log/ })).toBeTruthy()
  expect(await ui.find({ type: 'Text', text: /✘ tail -f gone\.log/ })).toBeFalsy()
  await ui.unmount()
})

test('the background timer counts from when the command started', async ($, on) => {
  const { clock } = engine(on)
  on('tool.call', async () => {
    await clock.advance(1_500)
    return { result: {}, text: BG }
  })
  mockFile(on, () => 'running')
  await $.tool.call({ tool: 'Bash', command: 'npm run dev', run_in_background: true })
  await clock.advance(2_000)
  const ui = await $.ui.mount({ ...BAND, surface: 'terminal' })
  expect(await ui.find({ type: 'Text', text: /npm run dev  0:04/ })).toBeTruthy()
  await ui.unmount()
})

test('a hidden finished card is dropped, and more than three cards show "+N more"', async ($, on) => {
  const { clock } = engine(on)
  let n = 0
  on('tool.call', () => { n += 1; return { result: {}, text: BG.replace('abc123', `t${n}`).replace('x/tasks', `x/tasks`) } })
  mockFile(on, () => 'running')
  for (let i = 0; i < 5; i += 1) {
    await $.tool.call({ tool: 'Bash', command: `job ${i}`, run_in_background: true })
  }
  await clock.advance(100)
  const ui = await $.ui.mount({ ...BAND, surface: 'terminal' })
  expect(await ui.find({ type: 'Text', text: /\+2 more/ })).toBeTruthy()
  expect(await ui.find({ type: 'Text', text: /running more/ })).toBeFalsy()
  await ui.unmount()
})
