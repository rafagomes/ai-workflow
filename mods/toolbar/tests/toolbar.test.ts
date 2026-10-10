import { expect, mock, test } from 'claude-code/testing'
import type { Engine } from 'claude-code/testing'
import type { CommandRunInput, On, RenderElement, RenderPropsOf } from 'claude-code'

// Only the props the mod reads; the engine fills the rest in a session.
const BAND = { hasSurvey: false, isWorking: false, maxRows: 20, bodyColumns: 120 } as RenderPropsOf['AbovePrompt']
const HINT: RenderPropsOf['PromptHint'] = { isDraft: false, isWorking: false, hint: '? for shortcuts' }

const START = { cwd: '/repo', surface: 'terminal', isInteractive: true } as const
const OPTIONS = ['default', 'sonnet', 'opus', 'haiku', 'fable', 'sonnet[1m]', 'opus[1m]', 'fable[1m]']
const MODELS = ['haiku', 'sonnet', 'opus', 'fable']
const EFFORTS = ['low', 'medium', 'high', 'xhigh', 'max']

// The session beneath the mod: /model and /effort change it as the built-in
// commands would, and every command the mod runs is recorded. `beneath` is
// what another plugin draws in the band, absent for the engine's own (empty).
const world = (
  on: On,
  given: { model?: string; effortLevel?: string; refuses?: string; beneath?: string; editorExit?: number | 'throws' } = {},
) => {
  const session = {
    model: given.model ?? 'claude-sonnet-5-5',
    ran: [] as string[],
    spawned: [] as string[][],
    toasts: [] as string[],
    clock: mock.clock(on),
  }

  on('session.root', () => ({ value: '/repo' }) as never)
  on('process.run', (_$, e) => {
    session.spawned.push([...e.argv])

    if (given.editorExit === 'throws') {
      throw new Error('open is missing')
    }

    return { value: { exitCode: given.editorExit ?? 0, stdout: '', stderr: '' } } as never
  })

  on('command.register', (_$, e) => ({ value: { command: e.name } }) as never)
  on('session.start', (_$, e) => ({ cwd: e.cwd }) as never)
  on('session.model', () => ({ value: session.model }) as never)
  on('config.list', () => ({ value: [{ key: 'model', options: OPTIONS }] }) as never)
  on('settings.read', () => ({ value: { effortLevel: given.effortLevel } }) as never)
  on('ui.toast', (_$, e) => {
    session.toasts.push(e.text)

    return { value: undefined } as never
  })
  on('command.run', (_$, e) => {
    if (e.command === 'toolbar') {
      return { text: '' } as never
    }

    session.ran.push(`/${e.command} ${e.args}`)

    if (e.command === given.refuses) {
      throw new Error('refused')
    }

    if (e.command === 'model') {
      const long = e.args.endsWith('[1m]')
      session.model = `claude-${e.args.replace('[1m]', '')}-5-5${long ? '[1m]' : ''}`
    }

    return { text: 'ok' } as never
  })
  on('ui.render', ($, e) =>
    given.beneath === undefined || e.component !== 'AbovePrompt'
      ? ({ type: 'engine', ref: 0 } as RenderElement)
      : (h($.ui.resolve(e).Text, {}, given.beneath) as RenderElement),
  )

  return session
}

const band = ($: Engine, props: Partial<RenderPropsOf['AbovePrompt']> = {}) =>
  $.ui.mount({ plugin: 'toolbar', surface: 'terminal', component: 'AbovePrompt', props: { ...BAND, ...props } })

const hint = ($: Engine) =>
  $.ui.mount({ plugin: 'toolbar', surface: 'terminal', component: 'PromptHint', props: HINT })

// Presses the button under the prompt that opens and closes the card.
const toggle = async ($: Engine) => {
  const ui = await hint($)
  await ui.press({ key: 'toolbar' })
  await ui.unmount()
}

const press = async ($: Engine, ...keys: string[]) => {
  for (const key of keys) {
    const ui = await band($)
    await ui.press({ key })
    await ui.unmount()
  }
}

const isOpen = async ($: Engine) => {
  const ui = await band($)
  const done = await ui.find({ key: 'done' })
  await ui.unmount()

  return done !== undefined
}

// The marked option of a row is drawn as a highlight, not a button: the one
// name of the row with no button to press. "1m" is added while 1M is on.
const marked = async ($: Engine, row: 'model' | 'effort') => {
  const ui = await band($)
  const found: string[] = []

  for (const name of row === 'model' ? MODELS : EFFORTS) {
    if ((await ui.find({ key: `${row}-${name}` })) === undefined) {
      found.push(name)
    }
  }

  if (row === 'model' && (await ui.find({ key: 'model-1m' }))?.props.label === '● 1M') {
    found.push('1m')
  }

  await ui.unmount()

  return found
}

const shows = async ($: Engine, text: string) => {
  const ui = await band($)
  const found = await ui.find({ type: 'Text', text })
  await ui.unmount()

  return found !== undefined
}

test('closed, the band is empty and the hint row keeps its hint beside the button', async ($, on) => {
  world(on)

  await $.session.start(START)
  expect(await isOpen($)).toBe(false)

  const ui = await hint($)
  expect((await ui.find({ key: 'toolbar' }))?.props.label).toBe('◆ Toolbar ▾')
  expect(await ui.find({ type: 'Text', text: '? for shortcuts' })).toBeDefined()
  await ui.unmount()
})

test('the button opens the card, marked with what the session runs on', async ($, on) => {
  world(on, { model: 'claude-opus-5-5[1m]', effortLevel: 'high' })

  await $.session.start(START)
  await toggle($)

  expect(await isOpen($)).toBe(true)
  expect(await marked($, 'model')).toEqual(['opus', '1m'])
  expect(await marked($, 'effort')).toEqual(['high'])
  expect(await shows($, 'Opus 5.5 1M · High')).toBe(true)
  expect(await shows($, ' Opus 5.5 ')).toBe(true)
  expect(await shows($, 'claude-opus-5-5[1m]')).toBe(true)

  const ui = await hint($)
  expect((await ui.find({ key: 'toolbar' }))?.props.label).toBe('◆ Toolbar ▴')
  await ui.unmount()
})

test('picks only mark the card; Done runs /model and /effort once each', async ($, on) => {
  const session = world(on, { effortLevel: 'medium' })

  await $.session.start(START)
  await toggle($)
  await press($, 'model-haiku', 'model-opus', 'effort-high', 'effort-xhigh')

  expect(session.ran).toEqual([])
  expect(await marked($, 'model')).toEqual(['opus'])
  expect(await marked($, 'effort')).toEqual(['xhigh'])
  expect(await shows($, 'applies when closed')).toBe(true)

  await press($, 'done')
  expect(await isOpen($)).toBe(false)
  expect(session.ran).toEqual(['/model opus', '/effort xhigh'])

  await toggle($)
  expect(await marked($, 'model')).toEqual(['opus'])
  expect(await marked($, 'effort')).toEqual(['xhigh'])
  expect(await shows($, 'applies when closed')).toBe(false)
})

test('closing with nothing new picked runs nothing', async ($, on) => {
  const session = world(on, { effortLevel: 'medium' })

  await $.session.start(START)
  await toggle($)
  await press($, 'model-opus', 'model-sonnet', 'effort-high', 'effort-medium', 'done')
  await toggle($)
  await toggle($)

  expect(session.ran).toEqual([])
})

test('the button under the prompt closes the card and applies the picks too', async ($, on) => {
  const session = world(on, { effortLevel: 'medium' })

  await $.session.start(START)
  await toggle($)
  await press($, 'effort-low')
  await toggle($)

  expect(await isOpen($)).toBe(false)
  expect(session.ran).toEqual(['/effort low'])
})

test('1M toggles the long-context variant and model picks keep it', async ($, on) => {
  const session = world(on)

  await $.session.start(START)
  await toggle($)
  await press($, 'model-1m')
  expect(await marked($, 'model')).toEqual(['sonnet', '1m'])

  await press($, 'model-fable')
  expect(await marked($, 'model')).toEqual(['fable', '1m'])

  // haiku has no 1M variant in this build, so it is picked plain.
  await press($, 'model-haiku')
  expect(await marked($, 'model')).toEqual(['haiku'])

  await press($, 'model-fable', 'model-1m', 'done')
  expect(session.ran).toEqual(['/model fable[1m]'])
})

test('a refused command leaves the marks where they were', async ($, on) => {
  const session = world(on, { effortLevel: 'medium', refuses: 'effort' })

  await $.session.start(START)
  await toggle($)
  await press($, 'effort-max', 'done')
  expect(session.ran).toEqual(['/effort max'])

  await toggle($)
  expect(await marked($, 'effort')).toEqual(['medium'])
})

test('follows the effort a turn really ran at', async ($, on) => {
  world(on, { effortLevel: 'max' })
  on('classic.Stop', () => ({}) as never)

  await $.session.start(START)
  await $.classic.Stop({ stop_hook_active: false, effort: { level: 'high' } } as never)
  await toggle($)

  expect(await marked($, 'effort')).toEqual(['high'])
})

test('/toolbar toggles the card and applies the picks when it closes it', async ($, on) => {
  const session = world(on)

  await $.command.run({ command: 'toolbar', args: '' } as CommandRunInput)
  expect(await isOpen($)).toBe(true)

  await press($, 'model-opus')
  await $.command.run({ command: 'toolbar', args: '' } as CommandRunInput)
  await session.clock.settle()
  expect(await isOpen($)).toBe(false)
  expect(session.ran).toEqual(['/model opus'])

  await toggle($)
  await $.command.run({ command: 'toolbar', args: 'close' } as CommandRunInput)
  await session.clock.settle()
  expect(await isOpen($)).toBe(false)
})

test("keeps another plugin's band above the card, and yields to a survey", async ($, on) => {
  world(on, { beneath: '3 commits behind origin/main' })

  expect(await shows($, '3 commits behind origin/main')).toBe(true)

  await toggle($)
  expect(await shows($, '3 commits behind origin/main')).toBe(true)
  expect(await isOpen($)).toBe(true)

  const survey = await band($, { hasSurvey: true })
  expect(await survey.find({ key: 'done' })).toBeUndefined()
  await survey.unmount()
})

test("Open in VS Code opens the project's root and leaves the card open", async ($, on) => {
  const session = world(on)

  await $.session.start(START)
  await toggle($)
  await press($, 'editor')

  expect(session.spawned).toEqual([['open', '-a', 'Visual Studio Code', '/repo']])
  expect(session.toasts).toEqual([])
  expect(await isOpen($)).toBe(true)
})

test('says so when VS Code does not open', async ($, on) => {
  const session = world(on, { editorExit: 1 })

  await $.session.start(START)
  await toggle($)
  await press($, 'editor')

  expect(session.spawned).toHaveLength(1)
  expect(session.toasts).toEqual(['VS Code did not open'])
})

test('says so when open cannot run at all', async ($, on) => {
  const session = world(on, { editorExit: 'throws' })

  await $.session.start(START)
  await toggle($)
  await press($, 'editor')

  expect(session.spawned).toHaveLength(1)
  expect(session.toasts).toEqual(['VS Code did not open'])
})
