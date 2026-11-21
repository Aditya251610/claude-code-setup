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

const A1 = { id: 'a1', description: 'scan the repo', type: 'researcher', name: 'researcher', status: 'running', kind: 'local_agent',
  label: 'reading src/main.rs', startTime: NOW - 83_000, model: 'claude-sonnet-5-5', contextWindowSize: 200_000,
  tokenCount: 12_000, usage: [{ model: 'claude-sonnet-5-5', output_tokens: 2_100 }], cost: { usd: 0.04 } }

test('the token box shows context, both limits, cost; the agents line says none running', async ($, on) => {
  engine(on, [])
  for (const surface of ['terminal', 'desktop'] as const) {
    const ui = await $.ui.mount({ ...PANE, surface })
    expect((await ui.find({ type: 'Text', text: /TOKENS/ }))?.text).toBe('TOKENS')
    expect(await ui.find({ type: 'Text', text: /42%/ })).toBeTruthy()
    expect(await ui.find({ type: 'Text', text: /5 hour/ })).toBeTruthy()
    expect(await ui.find({ type: 'Text', text: /est \$1\.82/ })).toBeTruthy()
    expect(await ui.find({ type: 'Text', text: /none running/ })).toBeTruthy()
    await ui.unmount()
  }
})

test('with agents running and none opened, the pane shows only a one-line summary', async ($, on) => {
  engine(on, [A1])
  const ui = await $.ui.mount({ ...PANE, surface: 'terminal' })
  expect(await ui.find({ type: 'Text', text: /1 running/ })).toBeTruthy()
  expect(await ui.find({ type: 'Text', text: /ctx 12k/ })).toBeFalsy()
  await ui.unmount()
})

test('opening an agent shows its details, recent calls, and Back and Stop buttons', async ($, on) => {
  engine(on, [A1])
  on('tool.call', () => ({ result: {}, text: 'ok' }))
  await $.tool.call({ tool: 'Read', file_path: '/src/main.rs', agentId: 'a1' })
  const ui = await $.ui.mount({ ...PANE, surface: 'terminal', props: { ...PANE.props, view: { agentId: 'a1' } } })
  expect(await ui.find({ type: 'Text', text: /researcher/ })).toBeTruthy()
  expect(await ui.find({ type: 'Text', text: /sonnet-5-5/ })).toBeTruthy()
  expect(await ui.find({ type: 'Text', text: /1:23/ })).toBeTruthy()
  expect(await ui.find({ type: 'Text', text: /out 2\.1k/ })).toBeTruthy()
  expect(await ui.find({ type: 'Text', text: /est \$0\.04/ })).toBeTruthy()
  expect(await ui.find({ type: 'Text', text: /Read \/src\/main\.rs/ })).toBeTruthy()
  expect(await ui.find({ type: 'Button', label: /Back/ })).toBeTruthy()
  expect(await ui.find({ type: 'Button', label: /^Stop/ })).toBeTruthy()
  await ui.unmount()
})

test('Back returns the main view; Stop needs a second press and then calls TaskStop', async ($, on) => {
  engine(on, [A1])
  const views: unknown[] = []
  const calls: any[] = []
  on('ui.view', (_: unknown, e: any) => { views.push(e); return { value: {} } })
  on('tool.call', (_: unknown, e: any) => { calls.push(e); return { result: {}, text: 'Successfully stopped' } })
  const ui = await $.ui.mount({ ...PANE, surface: 'terminal', props: { ...PANE.props, view: { agentId: 'a1' } } })

  await ui.press({ key: 'back' })
  expect(views.length).toBe(1)

  await ui.press({ key: 'stop' })
  expect(calls.filter((c) => c.tool === 'TaskStop').length).toBe(0)
  await ui.press({ key: 'stop' })
  expect(calls.filter((c) => c.tool === 'TaskStop').length).toBe(1)
  await ui.unmount()
})
