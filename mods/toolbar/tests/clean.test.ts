import { expect, mock, test } from 'claude-code/testing'
import type { Engine } from 'claude-code/testing'
import type { On, RenderElement, RenderPropsOf } from 'claude-code'

// Only the props the mod reads; the engine fills the rest in a session.
const BAND = { hasSurvey: false, isWorking: false, maxRows: 20, bodyColumns: 120 } as RenderPropsOf['AbovePrompt']
const HINT: RenderPropsOf['PromptHint'] = { isDraft: false, isWorking: false, hint: '? for shortcuts' }
const PROMPT = {
  model: 'claude-opus-5-5',
  promptModel: 'claude-opus-5-5',
  surfaces: ['terminal'],
  tools: [],
  outputStyle: null,
  traits: [],
} as const
const ROW = 'the row as the engine draws it'

// The session beneath the mod: task tools that answer as the built-in ones,
// turns that start and end, and transcript rows drawn as one line of text.
// How many headings the small model was asked for, over the tests so far.
let asked = 0

const world = (on: On) => {
  let made = 0
  const clock = mock.clock(on)

  on('session.model', () => ({ value: 'claude-opus-5-5' }) as never)
  on('turn.start', (_$, e) => ({ turnId: e.turnId }))
  on('prompt.submit', (_$, e) => ({ text: e.text }) as never)
  // The small model names a turn "Named <prompt>", or fails when asked to.
  on('model.complete', (_$, e) => {
    asked += 1

    return {
      value:
        e.prompt === 'unnamed'
          ? { isAnswered: false, reason: 'api-error' }
          : { isAnswered: true, text: `**"Named ${e.prompt}".**\nand a second line` },
    } as never
  })
  on('turn.complete', (_$, e) => ({ text: e.answer }))
  on('prompt.compose', () => ({ sections: [{ id: 'intro', text: 'You are Claude.', scope: 'shared' }] }) as never)
  on('tool.call', (_$, e) => {
    if (e.tool === 'TaskCreate') {
      made += 1

      return { result: { task: { id: String(made), subject: e.subject } } } as never
    }

    return { result: {} } as never
  })
  on('ui.render', ($, e) =>
    e.component === 'AbovePrompt' || e.component === 'PromptHint'
      ? ({ type: 'engine', ref: 0 } as RenderElement)
      : (h($.ui.resolve(e).Text, {}, ROW) as RenderElement),
  )

  return clock
}

const mount = ($: Engine, component: string, props: unknown) =>
  $.ui.mount({ plugin: 'toolbar', surface: 'terminal', component, props } as never)

const press = async ($: Engine, component: string, props: unknown, key: string) => {
  const ui = await mount($, component, props)
  await ui.press({ key })
  await ui.unmount()
}

// Opens the card, presses the Clean View switch and closes the card again.
const flip = async ($: Engine) => {
  await press($, 'PromptHint', HINT, 'toolbar')
  await press($, 'AbovePrompt', BAND, 'clean')
  await press($, 'PromptHint', HINT, 'toolbar')
}

const shows = async ($: Engine, component: string, props: unknown, text: string) => {
  const ui = await mount($, component, props)
  const found = await ui.find({ type: 'Text', text })
  await ui.unmount()

  return found !== undefined
}

const inBand = ($: Engine, text: string) => shows($, 'AbovePrompt', BAND, text)

// One row of the band as it reads, bar included: the innermost box showing
// the text, undefined when none does.
const row = async ($: Engine, text: RegExp) => {
  const ui = await mount($, 'AbovePrompt', BAND)
  const found = await ui.findAll({ type: 'Box', text })
  await ui.unmount()

  return found.at(-1)?.text
}

const task = ($: Engine, subject: string) => row($, new RegExp(`${subject}.*(Done|Working|Next|Up next)$`))
const total = ($: Engine) => row($, /^Step \d+ of \d+[▉░]+$/)
const bar = (filled: number, width = 20) => '▉'.repeat(filled) + '░'.repeat(width - filled)
// The bar of a task in progress: its lit run, this many cells along.
const run = (at: number) => '░'.repeat(at) + '▉'.repeat(4) + '░'.repeat(16 - at)
const drawn = ($: Engine, component: string, props: unknown = {}) => shows($, component, props, ROW)

// A turn the person starts: their prompt, then the turn it opens.
const start = async ($: Engine, turnId = 't1', text = 'implement it') => {
  await $.prompt.submit({ text, wait: false, origin: { kind: 'composer' } } as never)

  return $.turn.start({ text, turnId })
}
const end = ($: Engine, answer: string, extra: object = {}) =>
  $.turn.complete({ turnId: 't1', reason: 'answer', answer, durationMs: 10, ...extra } as never)
const create = ($: Engine, subject: string) =>
  $.tool.call({ tool: 'TaskCreate', subject, description: subject } as never)
const update = ($: Engine, taskId: string, status: string) =>
  $.tool.call({ tool: 'TaskUpdate', taskId, status } as never)

test('the card switches clean view on and off', async ($, on) => {
  world(on)

  await press($, 'PromptHint', HINT, 'toolbar')
  const off = await mount($, 'AbovePrompt', BAND)
  expect((await off.find({ key: 'clean' }))?.props.label).toBe('○ Off')
  await off.press({ key: 'clean' })
  await off.unmount()

  const turned = await mount($, 'AbovePrompt', BAND)
  expect((await turned.find({ key: 'clean' }))?.props.label).toBe('● On')
  await turned.press({ key: 'clean' })
  await turned.unmount()

  expect(await drawn($, 'ToolUse')).toBe(true)
})

test('on, the rows of the work draw nothing; off, they are back', async ($, on) => {
  world(on)

  for (const component of ['ToolUse', 'ToolResult', 'ToolGroup', 'ToolProgress', 'Spinner', 'TurnDuration']) {
    expect(await drawn($, component)).toBe(true)
  }

  await flip($)

  for (const component of ['ToolUse', 'ToolResult', 'ToolGroup', 'ToolProgress', 'Spinner', 'TurnDuration']) {
    expect(await drawn($, component)).toBe(false)
  }

  await flip($)
  expect(await drawn($, 'ToolUse')).toBe(true)
})

test("of the model's text only what the turn ended with is drawn", async ($, on) => {
  world(on)
  await flip($)
  await start($)

  const between = { text: 'Let me look at the files first.', isFirstOfReply: true }
  const final = { text: 'Done: three files changed, tests pass.', isFirstOfReply: true }

  expect(await drawn($, 'AssistantMessage', between)).toBe(false)
  expect(await drawn($, 'AssistantMessage', final)).toBe(false)

  await end($, 'Done: three files changed, tests pass.')
  expect(await drawn($, 'AssistantMessage', between)).toBe(false)
  expect(await drawn($, 'AssistantMessage', final)).toBe(true)

  // The summary of the turn before stays while the next one works.
  await start($, 't2')
  expect(await drawn($, 'AssistantMessage', final)).toBe(true)

  await flip($)
  expect(await drawn($, 'AssistantMessage', between)).toBe(true)
})

test('on, a background task reporting in draws nothing; what the person typed stays', async ($, on) => {
  world(on)
  const typed = { text: 'review it', origin: { kind: 'composer' }, isExpanded: false }
  const reported = { text: 'Agent finished', origin: { kind: 'task-notification' }, isExpanded: false }

  expect(await drawn($, 'UserMessage', reported)).toBe(true)

  await flip($)
  expect(await drawn($, 'UserMessage', typed)).toBe(true)
  expect(await drawn($, 'UserMessage', reported)).toBe(false)
  expect(await drawn($, 'UserMessage', { ...reported, task: { status: 'completed' } })).toBe(false)
  expect(await drawn($, 'UserMessage', { ...reported, task: { status: 'failed' } })).toBe(true)
  expect(await drawn($, 'UserMessage', { ...reported, isExpanded: true })).toBe(true)
})

test("a background task's own turn leaves the answer to the person drawn", async ($, on) => {
  world(on)
  const row = (text: string) => ({ text, isFirstOfReply: true })
  const submit = (kind: string, text: string, turnId?: string) =>
    $.prompt.submit({ text, wait: false, origin: { kind }, turnId } as never)
  const turn = (text: string, turnId: string) => $.turn.start({ text, turnId })
  await flip($)

  // Before the person asked anything, a task's message takes no answer's place.
  await submit('task-notification', 'agent zero ended')
  await turn('agent zero ended', 't0')
  await end($, 'Agent zero is done.')
  expect(await drawn($, 'AssistantMessage', row('Agent zero is done.'))).toBe(true)

  await submit('composer', 'review it')
  await turn('review it', 't1')
  expect(await inBand($, 'Named review it')).toBe(true)
  await end($, 'The answer.')
  expect(await drawn($, 'AssistantMessage', row('Agent zero is done.'))).toBe(false)

  await submit('task-notification', 'agent one ended')
  await turn('agent one ended', 't2')
  expect(await inBand($, 'Named review it')).toBe(true)
  expect(await inBand($, 'agent one ended')).toBe(false)

  // Typed over the task's turn, then another task reports in before it starts.
  await submit('composer', 'now fix it', 't2')
  await end($, 'Agent one is done.')
  await submit('peer', 'a peer says hello')
  await turn('a peer says hello', 't3')
  await end($, 'Told the peer.')
  expect(await drawn($, 'AssistantMessage', row('The answer.'))).toBe(true)
  expect(await drawn($, 'AssistantMessage', row('Agent one is done.'))).toBe(false)
  expect(await drawn($, 'AssistantMessage', row('Told the peer.'))).toBe(true)

  await turn('now fix it', 't4')
  expect(await inBand($, 'Named now fix it')).toBe(true)
  await end($, 'Fixed.')
  expect(await drawn($, 'AssistantMessage', row('The answer.'))).toBe(false)
  expect(await drawn($, 'AssistantMessage', row('Told the peer.'))).toBe(false)
  expect(await drawn($, 'AssistantMessage', row('Fixed.'))).toBe(true)
})

test('the band never reads the prompt back: no heading when the model gives none', async ($, on) => {
  world(on)
  await flip($)
  await start($, 't1', 'unnamed')

  expect(await inBand($, 'working, no task list yet')).toBe(true)
  expect(await inBand($, 'unnamed')).toBe(false)
  expect(await inBand($, '✳')).toBe(false)
})

test('the heading is the model\'s words bare, and none is asked for while clean view is off', async ($, on) => {
  world(on)
  asked = 0

  await start($)
  expect(asked).toBe(0)

  await flip($)
  await start($, 't2')
  expect(asked).toBe(1)

  const ui = await mount($, 'AbovePrompt', BAND)
  expect((await ui.find({ type: 'Text', text: 'Named' }))?.text).toBe('✳ Named implement it ')
  await ui.unmount()
})

test('a prompt whose sender is unknown is never sent for a heading', async ($, on) => {
  world(on)
  await flip($)
  asked = 0
  await $.turn.start({ text: 'who sent this', turnId: 't1' })

  expect(asked).toBe(0)
  expect(await inBand($, 'Named')).toBe(false)
})

test('only the latest answer stays drawn', async ($, on) => {
  world(on)
  await flip($)
  await start($)
  await end($, 'First answer.')
  await start($, 't2')
  expect(await drawn($, 'AssistantMessage', { text: 'First answer.', isFirstOfReply: true })).toBe(true)

  await end($, 'Second answer.')
  expect(await drawn($, 'AssistantMessage', { text: 'First answer.', isFirstOfReply: true })).toBe(false)
  expect(await drawn($, 'AssistantMessage', { text: 'Second answer.', isFirstOfReply: true })).toBe(true)
})

test('the band lists the steps, each with its bar and what it is waiting for', async ($, on) => {
  world(on)
  await flip($)
  await start($)
  expect(await inBand($, 'Named implement it')).toBe(true)
  expect(await inBand($, 'working, no task list yet')).toBe(true)

  await create($, 'Write the parser')
  await create($, 'Add the tests')
  await create($, 'Update the docs')
  await create($, 'Run the checks')
  expect(await total($)).toBe(`Step 1 of 4${bar(0, 77)}`)
  expect(await task($, 'Write the parser')).toBe(`○ Write the parser${bar(0)}Next`)
  expect(await task($, 'Add the tests')).toBe(`○ Add the tests${bar(0)}Up next`)

  await update($, '1', 'completed')
  await update($, '2', 'in_progress')
  await update($, '4', 'deleted')
  expect(await total($)).toBe(`Step 2 of 3${bar(26, 77)}`)
  expect(await task($, 'Write the parser')).toBe(`✔ Write the parser${bar(20)}Done`)
  expect(await task($, 'Add the tests')).toBe(`● Add the tests${run(0)}Working`)
  expect(await task($, 'Update the docs')).toBe(`○ Update the docs${bar(0)}Next`)
  expect(await task($, 'Run the checks')).toBeUndefined()
})

test('the bar of a step in progress goes to the end and back while the turn works', async ($, on) => {
  const clock = world(on)
  await flip($)
  await start($)
  await create($, 'Write the parser')
  await create($, 'Add the tests')
  await clock.advance(600)
  expect(await task($, 'Write the parser')).toBe(`○ Write the parser${bar(0)}Next`)

  await update($, '1', 'in_progress')
  await update($, '2', 'in_progress')
  expect(await task($, 'Write the parser')).toBe(`● Write the parser${run(0)}Working`)

  await clock.advance(360)
  expect(await task($, 'Write the parser')).toBe(`● Write the parser${run(3)}Working`)
  expect(await task($, 'Add the tests')).toBe(`● Add the tests${run(3)}Working`)
  expect(await total($)).toBe(`Step 1 of 2${bar(0, 77)}`)

  // 16 cells to the end, then back: 20 ticks in, it is 4 from the end.
  await clock.advance(120 * 17)
  expect(await task($, 'Write the parser')).toBe(`● Write the parser${run(12)}Working`)

  await end($, 'Stopped half way.')
  await clock.advance(1200)
  expect(await task($, 'Write the parser')).toBe(`● Write the parser${run(12)}Working`)
})

test('a band too narrow for its columns is still drawn', async ($, on) => {
  world(on)
  await flip($)
  await start($)
  await create($, 'Write the parser')
  await update($, '1', 'in_progress')

  for (const bodyColumns of [0, 5, 20, 40]) {
    const ui = await mount($, 'AbovePrompt', { ...BAND, bodyColumns })
    expect(await ui.find({ type: 'Text', text: 'Write the parser' })).toBeDefined()
    await ui.unmount()
  }
})

test('a finished list stays until the next turn; an unfinished one carries over', async ($, on) => {
  world(on)
  await flip($)
  await start($)
  await create($, 'Write the parser')
  await create($, 'Add the tests')
  await update($, '1', 'completed')
  await update($, '2', 'in_progress')
  await end($, 'Stopped half way.')

  await start($, 't2')
  expect(await task($, 'Write the parser')).toBe(`✔ Write the parser${bar(20)}Done`)
  expect(await task($, 'Add the tests')).toBe(`● Add the tests${run(0)}Working`)

  await update($, '2', 'completed')
  await end($, 'All done.')
  expect(await total($)).toBe(`Step 2 of 2${bar(77, 77)}`)
  expect(await task($, 'Add the tests')).toBe(`✔ Add the tests${bar(20)}Done`)

  await start($, 't3')
  expect(await inBand($, 'Add the tests')).toBe(false)
  expect(await inBand($, 'working, no task list yet')).toBe(true)
})

test('a TodoWrite list is followed too', async ($, on) => {
  world(on)
  await flip($)
  await $.tool.call({
    tool: 'TodoWrite',
    todos: [
      { content: 'One', status: 'completed', activeForm: 'Doing one' },
      { content: 'Two', status: 'pending', activeForm: 'Doing two' },
    ],
  } as never)

  expect(await total($)).toBe(`Step 2 of 2${bar(39, 77)}`)
  expect(await task($, 'One')).toBe(`✔ One${bar(20)}Done`)
  expect(await task($, 'Two')).toBe(`○ Two${bar(0)}Next`)
})

test('off, the band shows no list; tasks made meanwhile show once it is on', async ($, on) => {
  world(on)
  await start($)
  await create($, 'Write the parser')
  expect(await inBand($, 'Write the parser')).toBe(false)

  await flip($)
  expect(await inBand($, 'Write the parser')).toBe(true)
})

test("a subagent's turn ending leaves the main one working", async ($, on) => {
  world(on)
  await flip($)
  await start($)
  await end($, 'Subagent report.', { agentId: 'a1' })

  expect(await inBand($, 'working, no task list yet')).toBe(true)
  expect(await drawn($, 'AssistantMessage', { text: 'Subagent report.', isFirstOfReply: true })).toBe(false)
})

test('on, the model is told what the person sees; off, the prompt is as it was', async ($, on) => {
  world(on)
  expect((await $.prompt.compose(PROMPT)).sections.map(one => one.id)).toEqual(['intro'])

  await flip($)
  const { sections } = await $.prompt.compose(PROMPT)
  expect(sections.map(one => one.id)).toEqual(['intro', 'toolbar-clean-view'])
  expect(sections[1]?.scope).toBe('session')
  expect(sections[1]?.text).toContain('task list')
})
