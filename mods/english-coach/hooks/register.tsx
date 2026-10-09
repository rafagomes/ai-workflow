import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register } from 'claude-code'

import type { Feedback, Issue } from '../types'

const MAX_CHARS = 3000
const last = atom({ plugin: 'english-coach', key: 'last' } as const, null)

export const SYSTEM = `You are an English coach for a Brazilian software engineer who wants to sound fluent and native, not just correct.
You receive one message they wrote to a coding assistant. Review two things:
1. grammar: tense, articles, prepositions, agreement, countable/uncountable nouns, spelling.
2. fluency: phrasing that is grammatical but unusual, literal translations from Portuguese, false friends, awkward word order, or word choices a native speaker wouldn't pick.
Ignore code, file paths, identifiers, commands, technical jargon, casual lowercase, and missing final punctuation. Don't nitpick choices natives commonly make in quick chat.
Reply with JSON only, no prose, no code fence:
{"issues":[{"kind":"grammar"|"fluency","original":"<exact short phrase>","improved":"<better phrase>","why":"<max 8 words>"}],"natural":"<whole message as a native would write it>"|null}
At most 5 issues. "natural" only when there are 2+ issues and the message is under 300 characters, else null. Nothing to improve: {"issues":[],"natural":null}`

// Drop pasted blocks and fenced code: they aren't the user's own writing.
export function ownWords(text: string): string {
  return text
    .replace(/<pasted_content[^>]*>[\s\S]*?<\/pasted_content[^>]*>/g, ' ')
    .replace(/```[\s\S]*?```/g, ' ')
    .trim()
}

// `raw` is what the user typed; `own` is it with pastes and code removed.
export function shouldCheck(raw: string, own: string): boolean {
  const head = raw.trimStart()
  if (head.startsWith('/') || head.startsWith('!')) return false
  return own.split(/\s+/).filter(Boolean).length >= 4
}

const isStr = (v: unknown): v is string => typeof v === 'string' && v.trim() !== ''

function parseJson(reply: string): unknown {
  try {
    return JSON.parse(reply.trim())
  } catch {
    // Prose around the object: retry from the first '{' to each '}' after it.
    const start = reply.indexOf('{')
    for (let end = reply.lastIndexOf('}'); start >= 0 && end > start; end = reply.lastIndexOf('}', end - 1)) {
      try {
        return JSON.parse(reply.slice(start, end + 1))
      } catch {}
    }
    return null
  }
}

// The model's reply is untrusted: keep only well-formed issues, and the
// rewrite only when the rules allow one.
export function parseFeedback(reply: string, textLength: number): Feedback | null {
  const raw = parseJson(reply)
  if (typeof raw !== 'object' || raw === null) return null
  const r = raw as { issues?: unknown; natural?: unknown }
  const issues: Issue[] = (Array.isArray(r.issues) ? r.issues : [])
    .filter(
      (i): i is Issue =>
        typeof i === 'object' && i !== null &&
        (i.kind === 'grammar' || i.kind === 'fluency') &&
        isStr(i.original) && isStr(i.improved) && i.original !== i.improved,
    )
    .slice(0, 5)
    .map(i => ({ kind: i.kind, original: i.original, improved: i.improved, why: isStr(i.why) ? i.why : '' }))
  const wantsNatural = issues.length >= 2 && textLength < 300
  return { issues, natural: wantsNatural && isStr(r.natural) ? r.natural : null }
}

export function asText(f: Feedback): string {
  const lines = f.issues.map(
    i => `  • [${i.kind}] "${i.original}" → "${i.improved}"${i.why ? ` — ${i.why}` : ''}`,
  )
  if (f.natural) lines.push(`  ✓ Natural: ${f.natural}`)
  return `✎ English\n${lines.join('\n')}`
}

// Bumped per prompt so a slow reply for an older prompt is discarded.
let generation = 0

async function check($: EngineInterface, text: string, gen: number) {
  const r = await $.model.complete({
    model: 'haiku',
    system: SYSTEM,
    prompt: text.slice(0, MAX_CHARS),
    maxTokens: 600,
  })
  if (!r.isAnswered) {
    $.ui.log(`english-coach: no reply (${r.reason})`, { to: 'debug' })
    return
  }
  if (gen !== generation) return
  const feedback = parseFeedback(r.text, text.length)
  if (feedback === null) {
    $.ui.log(`english-coach: unreadable reply: ${r.text.slice(0, 200)}`, { to: 'debug' })
    return
  }
  if (feedback.issues.length === 0) return
  await update($, last, () => feedback)
  $.ui.log(asText(feedback))
}

export const register: Register = on => {
  on('prompt.submit', async ($, e, next) => {
    const kind = e.origin.kind
    if (kind !== 'composer' && kind !== 'bridge') return next(e)

    // Any new prompt makes the previous feedback, and any check in flight, stale.
    const gen = ++generation
    await update($, last, () => null)
    const text = ownWords(e.text)
    if (shouldCheck(e.text, text)) {
      // Fire and forget: the turn starts right away; the check runs beside it.
      check($, text, gen).catch(err => $.ui.log(`english-coach: ${err}`, { to: 'debug' }))
    }
    return next(e)
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    const f = await read($, last)
    if (e.props.hasSurvey || f === null) return next(e)

    const { Box, Button, Text } = $.ui.resolve(e)
    return (
      <Box flexDirection="column" borderStyle="round" borderColor="suggestion" paddingX={1}>
        <Box justifyContent="space-between">
          <Text bold color="suggestion">✎ English coach</Text>
          <Button key="dismiss" label="Dismiss" onPress={() => update($, last, () => null)} />
        </Box>
        {f.issues.map((i, n) => (
          <Box key={`issue-${n}`} flexWrap="wrap">
            <Text>• </Text>
            <Text color={i.kind === 'grammar' ? 'warning' : 'permission'}>{i.kind === 'grammar' ? '[grammar] ' : '[fluency] '}</Text>
            <Text color="diffRemoved" strikethrough>{i.original}</Text>
            <Text> → </Text>
            <Text color="success" bold>{i.improved}</Text>
            {i.why ? <Text dimColor>{`  ${i.why}`}</Text> : null}
          </Box>
        ))}
        {f.natural ? (
          <Box marginTop={1}>
            <Text dimColor>Natural: </Text>
            <Text italic>{f.natural}</Text>
          </Box>
        ) : null}
      </Box>
    )
  })
}
