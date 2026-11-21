import { expect, test } from 'claude-code/testing'

const PANE = {
  plugin: 'agent-board',
  component: 'Pane',
  requestId: 'agent-board',
  props: { title: 'Board', isFocused: false, bodyColumns: 44, placement: 'dock', scroll: { offset: 0, bodyRows: 30 }, view: {} },
} as const

const NOW = 5_000_000

function engine(on: any, agents: unknown[]) {
  on('session.usage', () => ({
    value: {
      startedAt: 1,
      context: { tokens: 84_000, window: 200_000, percent: 42 },
      rateLimits: [
        { kind: 'five_hour', percentUsed: 23.5, resetsAt: new Date(NOW + 2 * 3_600_000 + 14 * 60_000).toISOString() },
        { kind: 'seven_day', percentUsed: 9, resetsAt: new Date(NOW + 4 * 86_400_000).toISOString() },
      ],
      cost: { usd: 1.82 },
    },
  }))
  on('agent.list', () => ({ value: agents }))
  on('clock.now', () => ({ value: NOW }))
}

test('the token box shows context, both limits, cost', async ($, on) => {
  engine(on, [])
  for (const surface of ['terminal', 'desktop'] as const) {
    const ui = await $.ui.mount({ ...PANE, surface })
    expect((await ui.find({ type: 'Text', text: /TOKENS/ }))?.text).toBe('TOKENS')
    expect(await ui.find({ type: 'Text', text: /42%/ })).toBeTruthy()
    expect(await ui.find({ type: 'Text', text: /5 hour/ })).toBeTruthy()
    expect(await ui.find({ type: 'Text', text: /est \$1\.82/ })).toBeTruthy()
    expect(await ui.find({ type: 'Text', text: /No subagents running/ })).toBeTruthy()
    await ui.unmount()
  }
})

test('running subagents each get a tile with model, time and tokens', async ($, on) => {
  engine(on, [
    { id: 'a1', description: 'scan the repo', type: 'researcher', name: 'researcher', status: 'running', kind: 'local_agent',
      label: 'reading src/main.rs', startTime: NOW - 83_000, model: 'claude-sonnet-5-5', contextWindowSize: 200_000,
      tokenCount: 12_000, usage: [{ model: 'claude-sonnet-5-5', output_tokens: 2_100 }], cost: { usd: 0.04 } },
    { id: 'a2', description: 'rename things', type: 'worker', status: 'running', kind: 'local_agent',
      label: 'editing 12 files', startTime: NOW - 9_000, model: 'claude-haiku-5-5', tokenCount: 3_000, usage: [] },
  ])
  const ui = await $.ui.mount({ ...PANE, surface: 'terminal' })
  expect(await ui.find({ type: 'Text', text: /2 running/ })).toBeTruthy()
  expect(await ui.find({ type: 'Text', text: /researcher/ })).toBeTruthy()
  expect(await ui.find({ type: 'Text', text: /1:23/ })).toBeTruthy()
  expect(await ui.find({ type: 'Text', text: /sonnet-5-5/ })).toBeTruthy()
  expect(await ui.find({ type: 'Text', text: /ctx 12k\/200k/ })).toBeTruthy()
  expect(await ui.find({ type: 'Text', text: /worker/ })).toBeTruthy()
  expect(await ui.find({ type: 'Text', text: /haiku-5-5/ })).toBeTruthy()
  await ui.unmount()
})
