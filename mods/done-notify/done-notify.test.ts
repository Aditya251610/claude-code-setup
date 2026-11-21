import { expect, test } from 'claude-code/testing'

// Which notifier each platform (as `$.session.info()` reports it) should use.
const TOOL: Record<string, string> = { linux: 'notify-send', wsl: 'notify-send', macos: 'osascript', windows: 'powershell' }

// Mocks must be registered once, before the first call of `$` in a test.
function setup(on: any, platform: string) {
  const runs: string[][] = []
  on('session.info', () => ({ value: { platform, isHosted: false } }))
  on('process.run', (_: unknown, e: any) => {
    runs.push([...(e.argv as string[])])
    return { value: { exitCode: 0, stdout: '', stderr: '' } }
  })
  on('turn.complete', () => ({ text: 'ok' }))
  return runs
}

const finish = ($: any, durationMs: number, reason = 'answer') =>
  $.turn.complete({ answer: 'ok', durationMs, isAborted: false, turnId: 't', reason })

for (const platform of Object.keys(TOOL)) {
  test(`${platform}: a long turn notifies with ${TOOL[platform]}, a short one does not`, async ($, on) => {
    const runs = setup(on, platform)
    await finish($, 5_000)
    expect(runs.length).toBe(0)
    await finish($, 90_000)
    expect(runs.some((a) => a[0] === TOOL[platform])).toBe(true)
  })

  test(`${platform}: the notification text is plain, so quotes and script characters are stripped`, async ($, on) => {
    const runs = setup(on, platform)
    await finish($, 90_000, 'x"; Remove-Item $HOME #')
    const text = (runs.find((a) => a[0] === TOOL[platform]) ?? []).join(' ')
    expect(text.length > 0).toBe(true)
    expect(text.includes('Remove-Item $HOME')).toBe(false)
    expect(text.includes('"; ')).toBe(false)
  })
}

test('an unknown platform stays quiet', async ($, on) => {
  const runs = setup(on, 'unknown')
  await finish($, 90_000)
  expect(runs.length).toBe(0)
})
