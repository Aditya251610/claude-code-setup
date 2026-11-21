import { expect, test } from 'claude-code/testing'

test('a long turn sends one notification, a short one none', async ($, on) => {
  const runs: string[][] = []
  on('process.run', (_, e) => {
    runs.push([...(e.argv as string[])])
    return { value: { exitCode: 0, stdout: 'Linux\n', stderr: '' } }
  })

  on('turn.complete', () => ({ text: 'ok' }))
  await $.turn.complete({ answer: 'ok', durationMs: 5_000, isAborted: false, turnId: 't1', reason: 'answer' })
  expect(runs.length).toBe(0)

  await $.turn.complete({ answer: 'ok', durationMs: 90_000, isAborted: false, turnId: 't2', reason: 'answer' })
  expect(runs.some((a) => a[0] === 'notify-send')).toBe(true)
})
