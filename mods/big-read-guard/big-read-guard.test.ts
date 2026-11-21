import { expect, test } from 'claude-code/testing'

test('a lockfile read whole is refused, a ranged read passes', async ($, on) => {
  on('tool.call', () => ({ result: {} }))
  on('fs.stat', () => ({ value: { kind: 'file', size: 10, mtimeMs: 0, isLink: false } }))

  const whole = await $.tool.call({ tool: 'Read', file_path: '/p/package-lock.json' })
  expect(String(whole.deny)).toContain('Big Read Guard')

  const ranged = await $.tool.call({ tool: 'Read', file_path: '/p/package-lock.json', offset: 1, limit: 20 })
  expect(ranged.deny).toBeUndefined()
})

test('a big file is refused and a small one passes', async ($, on) => {
  on('tool.call', () => ({ result: {} }))
  on('fs.stat', (_, e) => ({
    value: { kind: 'file', size: String(e.path).includes('big') ? 400_000 : 2_000, mtimeMs: 0, isLink: false },
  }))

  const big = await $.tool.call({ tool: 'Read', file_path: '/p/big.txt' })
  expect(String(big.deny)).toContain('400 KB')

  const small = await $.tool.call({ tool: 'Read', file_path: '/p/small.txt' })
  expect(small.deny).toBeUndefined()
})

test('an image is never size-checked', async ($, on) => {
  on('tool.call', () => ({ result: {} }))
  on('fs.stat', () => ({ value: { kind: 'file', size: 5_000_000, mtimeMs: 0, isLink: false } }))
  const png = await $.tool.call({ tool: 'Read', file_path: '/p/shot.png' })
  expect(png.deny).toBeUndefined()
})
