import { expect, test } from 'claude-code/testing'
import { asText, ownWords, parseFeedback, shouldCheck } from './register'

test('skips slash commands, shell escapes and very short input', () => {
  const own = (t: string) => shouldCheck(t, ownWords(t))
  expect(own('/clear')).toBe(false)
  expect(own('  /review the open pull request now')).toBe(false)
  expect(own('! ls -la /tmp now')).toBe(false)
  expect(own('yes do it')).toBe(false)
  expect(own('pull our new updates from ai-workflow')).toBe(true)
})

test('judges the prefix on what was typed, not the stripped text', () => {
  const t = '<pasted_content id="x">log</pasted_content>/etc/hosts is broken again here'
  expect(shouldCheck(t, ownWords(t))).toBe(true)
})

test('strips pasted content and code fences', () => {
  const t = 'look at this <pasted_content id="x">some log</pasted_content> and ```code``` please'
  expect(ownWords(t)).toBe('look at this   and   please')
})

test('parses a reply, dropping malformed issues', () => {
  const reply = 'Sure: {"issues":[{"kind":"grammar","original":"a feedback","improved":"feedback","why":"uncountable"},{"kind":"style","original":"x","improved":"y"},{"kind":"fluency","original":"same","improved":"same"}],"natural":"Give me feedback."}'
  expect(parseFeedback(reply, 40)).toEqual({
    issues: [{ kind: 'grammar', original: 'a feedback', improved: 'feedback', why: 'uncountable' }],
    natural: null,
  })
})

test('treats an empty or broken reply correctly', () => {
  expect(parseFeedback('{"issues":[],"natural":"ignored"}', 40)).toEqual({ issues: [], natural: null })
  expect(parseFeedback('looks fine', 40)).toBeNull()
  expect(parseFeedback('{not json}', 40)).toBeNull()
})

test('keeps the rewrite only for 2+ issues on a short message', () => {
  const two = '{"issues":[{"kind":"grammar","original":"a","improved":"b","why":""},{"kind":"fluency","original":"c","improved":"d","why":""}],"natural":"N"}'
  expect(parseFeedback(two, 120)?.natural).toBe('N')
  expect(parseFeedback(two, 2500)?.natural).toBeNull()
})

test('survives braces in prose around the JSON', () => {
  const reply = 'Result: {"issues":[{"kind":"grammar","original":"a","improved":"b","why":"x"}],"natural":null} (kept {braces} out)'
  expect(parseFeedback(reply, 40)?.issues.length).toBe(1)
})

test('formats a bulleted transcript line', () => {
  const text = asText({
    issues: [{ kind: 'fluency', original: 'not usual', improved: 'unusual', why: 'more idiomatic' }],
    natural: null,
  })
  expect(text).toBe('✎ English\n  • [fluency] "not usual" → "unusual" — more idiomatic')
})
