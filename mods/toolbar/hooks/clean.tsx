import { atom, read, update } from 'claude-code'
import type { EngineInterface, Register, Timer } from 'claude-code'

import type { Clean } from '../types'

// What the model is told while clean view is on: the task list and the final
// message are all the person sees, so both have to carry the turn.
const GUIDE = `# Clean view

The person has turned on clean view: your tool calls, their results and the text you write between them are hidden. They see only your task list, with its progress, and the final message of your turn.

- For any work of more than one step, create the task list before you start, one task per step, and keep every status current as you go: in progress when you begin a step, completed as soon as it is done.
- End the turn with a summary that stands by itself: what was done, what was verified and how, what failed or was left out, and anything the person has to decide or run.
- A question or a blocker goes in that final message too; nothing written earlier in the turn is read.`

// The longest heading the band draws before it is cut with an ellipsis.
const TITLE = 60

export const EMPTY: Clean = { on: false, working: false, tasks: [], finals: [], title: '', turnId: '' }

const headed = (text: string) => {
  const line = (text.trim().split('\n')[0] ?? '').trim()

  return line.length > TITLE ? `${line.slice(0, TITLE).trimEnd()}…` : line
}

// How often the loading bar of a task in progress moves one cell.
const BEAT = 120

const beat = atom({ plugin: 'toolbar', key: 'beat' } as const, 0)

const channels = (hex: string) => [1, 3, 5].map(at => parseInt(hex.slice(at, at + 2), 16))

// The color a fraction of the way along a list of hex stops.
export const mix = (stops: readonly string[], fraction: number) => {
  const at = Math.min(Math.max(fraction, 0), 1) * (stops.length - 1)
  const from = channels(stops[Math.floor(at)] ?? '#000000')
  const to = channels(stops[Math.ceil(at)] ?? '#000000')

  return `#${from
    .map((one, index) =>
      Math.round(one + ((to[index] ?? one) - one) * (at - Math.floor(at)))
        .toString(16)
        .padStart(2, '0'),
    )
    .join('')}`
}

const clean = atom({ plugin: 'toolbar', key: 'clean' } as const, EMPTY)

// The session keeps this value across reloads, so one saved by an older
// version of the mod may lack a field: every read and write starts from EMPTY.
export const wholeClean = (saved: Partial<Clean> | undefined): Clean => ({ ...EMPTY, ...saved })

const load = async ($: EngineInterface) => wholeClean(await read($, clean))

const change = ($: EngineInterface, fn: (one: Clean) => Clean) =>
  update($, clean, saved => fn(wholeClean(saved)))

// The final messages that stay drawn: the answer to what the person last
// asked, and after it the latest a background task's own turn ended with, so
// a task reporting in never takes the answer away.
const stop = ($: EngineInterface, final?: string, isAsked = true) =>
  change($, one => ({
    ...one,
    working: false,
    finals:
      final === undefined || final.trim() === ''
        ? one.finals
        : isAsked
          ? [final]
          : [one.finals[0] ?? '', final],
  }))

// Where a prompt the person sent comes from; any other origin is a task, a
// peer or a schedule speaking, and its turn does not replace their answer.
const PERSON = ['composer', 'bridge', 'sdk']
// How many prompts may wait for their turn before the oldest are forgotten.
const WAITING = 50

// What the small model is asked for: a heading that says what the turn is
// for, never the prompt read back.
const NAMER = `Name the task the user's message asks for, as a heading of 3 to 6 words in the language of the message. Answer with the heading alone: no quotes, no full stop. Do not answer the message.`

// Names the turn in the band. Until the heading arrives, and when none does,
// the band has none: the prompt itself is already on screen, right above it.
const entitle = async ($: EngineInterface, text: string, turnId: string) => {
  try {
    await change($, one => ({ ...one, title: '', turnId }))

    // Nothing is asked of the model for a band that is not drawn.
    if (text.trim() === '' || !(await load($)).on) {
      return
    }

    const named = await $.model.complete({
      model: 'haiku',
      system: NAMER,
      prompt: text.slice(0, 4000),
      maxTokens: 40,
      timeoutMs: 15000,
    })

    if (named.isAnswered) {
      // The heading is drawn as plain text: the marks a model may put round it go.
      const title = headed(named.text.replace(/[*_`#"“”]/g, '')).replace(/[.:]$/, '')
      // A later turn has its own heading on the way: this one is stale.
      await change($, one => (one.turnId === turnId ? { ...one, title } : one))
    }
  } catch {
    // No heading, then.
  }
}

// The loading bars move only while there is one to draw.
const tick = async ($: EngineInterface) => {
  const { on: isOn, tasks } = await load($)

  if (isOn && tasks.some(task => task.status === 'in_progress')) {
    await update($, beat, at => (at ?? 0) + 1)
  }
}

export const registerClean: Register = on => {
  let pulse: Timer | undefined

  const rest = () => {
    pulse?.cancel()
    pulse = undefined
  }

  // Whether the turn under way answers the person, and for each prompt still
  // to start its turn, whether the person sent it: a prompt typed over a
  // running turn waits, and a task may report in before it starts.
  let isAsked = true
  const sent = new Map<string, boolean>()

  on('prompt.submit', ($, e, next) => {
    if (sent.size >= WAITING) {
      sent.clear()
    }

    sent.set(e.text, PERSON.includes(e.origin.kind))

    return next(e)
  })

  // A list that was finished belongs to the turn before: the next starts clean.
  on('turn.start', async ($, e, next) => {
    rest()
    pulse = $.clock.every(BEAT, () => void tick($))
    const isPerson = sent.get(e.text)
    sent.delete(e.text)
    // A prompt whose sender is unknown (the module reloaded since it was sent)
    // is drawn as the person's, but its text is not sent anywhere for that.
    isAsked = isPerson ?? true

    if (isPerson === true) {
      // Not awaited: the turn does not wait for its heading.
      void entitle($, e.text, e.turnId)
    }
    await change($, one => ({
      ...one,
      working: true,
      tasks: one.tasks.every(task => task.status === 'completed') ? [] : one.tasks,
    }))

    return next(e)
  })

  on('turn.complete', async ($, e, next) => {
    // A subagent's turn ends inside the main one, which is still working.
    if (e.agentId === undefined) {
      rest()
      await stop($, e.answer, isAsked)
    }

    return next(e)
  })

  on('turn.abort', async ($, e, next) => {
    rest()
    await stop($)

    return next(e)
  })

  // The list is followed whether clean view is on or not, so turning it on in
  // the middle of a turn shows the tasks already made.
  on('tool.call', { tool: 'TaskCreate' }, async ($, e, next) => {
    const ran = await next(e)

    if (ran.deny === undefined && ran.isError !== true) {
      const { id, subject } = ran.result.task
      await change($, one => ({
        ...one,
        tasks: [...one.tasks.filter(task => task.id !== id), { id, subject, status: 'pending' }],
      }))
    }

    return ran
  })

  on('tool.call', { tool: 'TaskUpdate' }, async ($, e, next) => {
    const ran = await next(e)

    if (ran.deny === undefined && ran.isError !== true) {
      const { taskId, status, subject } = e
      await change($, one => ({
        ...one,
        tasks:
          status === 'deleted'
            ? one.tasks.filter(task => task.id !== taskId)
            : one.tasks.map(task =>
                task.id === taskId
                  ? { ...task, status: status ?? task.status, subject: subject ?? task.subject }
                  : task,
              ),
      }))
    }

    return ran
  })

  on('tool.call', { tool: 'TodoWrite' }, async ($, e, next) => {
    const ran = await next(e)

    if (ran.deny === undefined && ran.isError !== true) {
      const tasks = e.todos.map((todo, index) => ({
        id: String(index),
        subject: todo.content,
        status: todo.status,
      }))
      await change($, one => ({ ...one, tasks }))
    }

    return ran
  })

  on('prompt.compose', async ($, e, next) => {
    const composed = await next(e)

    if (!(await load($)).on) {
      return composed
    }

    return {
      ...composed,
      sections: [...composed.sections, { id: 'toolbar-clean-view', text: GUIDE, scope: 'session' }],
    }
  })

  // The rows of the work itself draw nothing while clean view is on; the
  // transcript keeps them, so turning it off shows them all again.
  on('ui.render', { component: 'ToolUse' }, async ($, e, next) => {
    const { Box } = $.ui.resolve(e)

    return (await load($)).on ? <Box /> : next(e)
  })

  on('ui.render', { component: 'ToolResult' }, async ($, e, next) => {
    const { Box } = $.ui.resolve(e)

    return (await load($)).on ? <Box /> : next(e)
  })

  on('ui.render', { component: 'ToolGroup' }, async ($, e, next) => {
    const { Box } = $.ui.resolve(e)

    return (await load($)).on ? <Box /> : next(e)
  })

  on('ui.render', { component: 'ToolProgress' }, async ($, e, next) => {
    const { Box } = $.ui.resolve(e)

    return (await load($)).on ? <Box /> : next(e)
  })

  // The engine's own line of the turn, with its copy of the task list, and the
  // line that closes it: the band says both while clean view is on.
  on('ui.render', { component: 'Spinner' }, async ($, e, next) => {
    const { Box } = $.ui.resolve(e)

    return (await load($)).on ? <Box /> : next(e)
  })

  on('ui.render', { component: 'TurnDuration' }, async ($, e, next) => {
    const { Box } = $.ui.resolve(e)

    return (await load($)).on ? <Box /> : next(e)
  })

  // A background task reporting that it ended is part of the work too; what
  // the person typed stays, and so does a task that failed or was stopped.
  on('ui.render', { component: 'UserMessage' }, async ($, e, next) => {
    const isDone = e.props.task?.status === undefined || e.props.task.status === 'completed'

    if (
      e.props.origin.kind !== 'task-notification' ||
      !isDone ||
      e.props.isExpanded ||
      !(await load($)).on
    ) {
      return next(e)
    }

    const { Box } = $.ui.resolve(e)

    return <Box />
  })

  // Of the model's text, only what those turns ended with is drawn.
  on('ui.render', { component: 'AssistantMessage' }, async ($, e, next) => {
    const { on: isOn, finals } = await load($)
    const text = e.props.text.trim()

    if (!isOn || (text !== '' && finals.some(final => final.includes(text)))) {
      return next(e)
    }

    const { Box } = $.ui.resolve(e)

    return <Box />
  })
}
