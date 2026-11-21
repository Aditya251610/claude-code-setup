import { expect, test } from 'claude-code/testing'

let clock = 1_000_000
function fakeClock(on: any) {
  on('clock.now', () => ({ value: (clock += 2_300) }))
  on('clock.every', () => ({ value: { cancel() {} } }))
}

test('a command toasts at start and again with the output tail at the end', async ($, on) => {
  const toasts: string[] = []
  on('ui.toast', (_, e) => { toasts.push(String(e.text)); return { value: undefined } })
  on('ui.status', () => ({ value: undefined }))
  fakeClock(on)
  on('tool.call', () => ({ result: {}, text: 'line1\nline2\nline3\nline4\nline5\nall done' }))

  await $.tool.call({ tool: 'Bash', command: 'make   test' })

  expect(toasts[0]).toBe('▶ make test')
  const last = toasts[toasts.length - 1]
  expect(last).toContain('✔ make test')
  expect(last).toContain('all done')
  expect(last).not.toContain('line1')
})

test('a failing command toasts a cross', async ($, on) => {
  const toasts: string[] = []
  on('ui.toast', (_, e) => { toasts.push(String(e.text)); return { value: undefined } })
  on('ui.status', () => ({ value: undefined }))
  fakeClock(on)
  on('tool.call', () => ({ result: {}, text: 'boom', isError: true }))

  await $.tool.call({ tool: 'Bash', command: 'false' })
  expect(toasts[toasts.length - 1]).toContain('✘ false')
})
