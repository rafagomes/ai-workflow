import { atom, read, update } from 'claude-code'
import type { CommandRunInput, EngineInterface, Register } from 'claude-code'

import type { Toolbar } from '../types'

import { EMPTY as CLEAN, mix, registerClean, wholeClean } from './clean'

// The card's width in columns: the model row on one line, inside the border.
const CARD = 66
const MODELS = [
  { name: 'haiku', label: 'Haiku 4.5' },
  { name: 'sonnet', label: 'Sonnet 5.5' },
  { name: 'opus', label: 'Opus 5.5' },
  { name: 'fable', label: 'Fable 5.1' },
]
const EFFORTS = [
  { name: 'low', label: 'Low' },
  { name: 'medium', label: 'Medium' },
  { name: 'high', label: 'High' },
  { name: 'xhigh', label: 'XHigh' },
  { name: 'max', label: 'Max' },
]
const LONG = '[1m]'

const NONE: Toolbar['pick'] = { model: null, effort: null }
const EMPTY: Toolbar = { model: '', effort: null, options: [], open: false, pick: NONE }
const view = atom({ plugin: 'toolbar', key: 'view' } as const, EMPTY)

// The session keeps this value across reloads, so one saved by an older
// version of the mod may lack a field: every read and write starts from EMPTY.
const whole = (saved: Partial<Toolbar> | undefined): Toolbar => ({
  ...EMPTY,
  ...saved,
  open: saved?.open === true,
})

const load = async ($: EngineInterface) => whole(await read($, view))

const change = ($: EngineInterface, fn: (one: Toolbar) => Toolbar) =>
  update($, view, saved => fn(whole(saved)))

const family = (model: string) => MODELS.find(one => model.toLowerCase().includes(one.name))
const isLong = (model: string) => model.toLowerCase().includes(LONG)
const isSameModel = (a: string, b: string) => family(a) === family(b) && isLong(a) === isLong(b)

// "Opus 5.5 1M · Medium": what the session runs on, in the card's corner.
const summary = (model: string, effort: string | null) =>
  [
    `${family(model)?.label ?? 'Model'}${isLong(model) ? ' 1M' : ''}`,
    EFFORTS.find(one => one.name === effort)?.label ?? effort,
  ]
    .filter(Boolean)
    .join(' · ')

// Runs a built-in command as the person typing it would: its own output row
// in the transcript is the confirmation. False when the engine refused it.
const run = async ($: EngineInterface, command: string, args: string) => {
  try {
    await $.command.run({ command, args } as CommandRunInput)

    return true
  } catch {
    $.ui.toast(`/${command} ${args} did not run`)

    return false
  }
}

const sync = async ($: EngineInterface) => {
  const model = await $.session.model()
  await change($, one => ({ ...one, model }))
}

const show = async ($: EngineInterface) => {
  await sync($)
  await change($, one => ({ ...one, open: true }))
}

const pick = ($: EngineInterface, picked: Partial<Toolbar['pick']>) =>
  change($, one => ({ ...one, pick: { ...one.pick, ...picked } }))

// Closing is what applies the picks: one /model and one /effort at most, and
// neither when the pick is what the session already has.
const close = async ($: EngineInterface) => {
  const { model, effort, pick: picked } = await load($)
  await change($, one => ({ ...one, open: false, pick: NONE }))

  if (picked.model !== null && !isSameModel(picked.model, model) && (await run($, 'model', picked.model))) {
    await sync($)
  }

  if (picked.effort !== null && picked.effort !== effort && (await run($, 'effort', picked.effort))) {
    const level = picked.effort
    await change($, one => ({ ...one, effort: level }))
  }
}

// The same value ./clean keeps: the card switches it, the band draws its list.
const clean = atom({ plugin: 'toolbar', key: 'clean' } as const, CLEAN)
// The ticks ./clean counts while a turn works: where the loading bars are.
const beat = atom({ plugin: 'toolbar', key: 'beat' } as const, 0)

const toggleClean = ($: EngineInterface) =>
  update($, clean, saved => ({ ...wholeClean(saved), on: !wholeClean(saved).on }))

// Opens the project's root in VS Code by the app's name, so it does not
// depend on the `code` launcher being on the host's PATH.
const openEditor = async ($: EngineInterface) => {
  try {
    const { exitCode } = await $.process.run(['open', '-a', 'Visual Studio Code', await $.session.root()])

    if (exitCode === 0) {
      return
    }
  } catch {
    // The toast below says it.
  }

  $.ui.toast('VS Code did not open')
}

// The clean view band: its widest, the columns of a task's own bar, of the
// lit run that crosses it while the task is in progress and of the word
// after it, and the gap between columns.
const BAND = 100
const BAR = 20
const RUN = 4
const NOTE = 8
const GAP = 2
const CELL = '▉'
const REST = '░'

const WARM = ['#f6a04d', '#ec4899']
const GREEN = ['#2f9e44', '#8ce99a']
const HEADING = ['#f6a04d', '#f472b6', '#c084fc', '#7aa2f7']

// The 1M-context variant of a model where this build has one, else the model.
const sized = (name: string, wantsLong: boolean, options: string[]) =>
  wantsLong && options.includes(`${name}${LONG}`) ? `${name}${LONG}` : name

export const register: Register = (on, options) => {
  registerClean(on, options)

  on('session.start', async ($, e, next) => {
    await sync($)

    try {
      const row = (await $.config.list()).find(one => one.key === 'model')
      const saved = (await $.settings.read()) as { effortLevel?: unknown }
      const effort = typeof saved.effortLevel === 'string' ? saved.effortLevel : null
      await change($, one => ({
        ...one,
        options: [...(row?.options ?? [])],
        effort: one.effort ?? effort,
      }))
    } catch {
      // Without them the rows still draw: every model, no effort marked.
    }

    await $.command.register({
      name: 'toolbar',
      description: 'Open or close the toolbar card above the prompt (model, effort, clean view, VS Code)',
      argumentHint: '[close]',
    })

    return next(e)
  })

  on('command.run', { command: 'toolbar' }, async ($, e) => {
    const { open } = await load($)
    const wantsOpen = e.args.trim() !== 'close' && !open

    if (wantsOpen) {
      await show($)
    } else {
      // A command cannot run another from inside its own hook: right after it.
      $.clock.after(0, () => close($))
    }

    return { text: wantsOpen ? 'Toolbar opened.' : 'Toolbar closed.' }
  })

  // The effort the turn really ran at: a change made by /effort, or a model
  // that downgraded it, shows here after the turn.
  on('classic.Stop', async ($, e, next) => {
    const level = e.effort?.level

    if (level !== undefined) {
      await change($, one => ({ ...one, effort: level }))
    }

    await sync($)

    return next(e)
  })

  // The button that opens the card sits at the right end of the hint row
  // under the prompt, beside the hint itself.
  on('ui.render', { component: 'PromptHint' }, async ($, e, next) => {
    const beneath = await next(e)
    const { Box, Button, Text } = $.ui.resolve(e)
    const { open } = await load($)

    return (
      <Box justifyContent="space-between" width="100%">
        {beneath.type === 'engine' ? (
          <Text dimColor wrap="truncate-end">
            {e.props.hint}
            {e.props.tail ?? ''}
          </Text>
        ) : (
          beneath
        )}
        <Button
          key="toolbar"
          label={open ? '◆ Toolbar ▴' : '◆ Toolbar ▾'}
          variant={open ? 'primary' : 'secondary'}
          onPress={() => (open ? close($) : show($))}
        />
      </Box>
    )
  })

  on('ui.render', { component: 'AbovePrompt' }, async ($, e, next) => {
    // What the plugins beneath draw in the band stays, above the card.
    const beneath = await next(e)
    const one = await load($)

    const view = wholeClean(await read($, clean))
    const hasList = view.on && (view.working || view.tasks.length > 0)

    if (e.props.hasSurvey || (!one.open && !hasList)) {
      return beneath
    }

    const { Box, Button, Text } = $.ui.resolve(e)
    const { tasks } = view
    const done = tasks.filter(task => task.status === 'completed').length
    const upcoming = tasks.find(task => task.status === 'pending')
    const share = tasks.length === 0 ? 0 : done / tasks.length
    const step = `Step ${Math.min(done + 1, tasks.length)} of ${tasks.length}`
    const inner = Math.min(BAND, e.props.bodyColumns ?? BAND)
    const cells = inner >= 60 ? BAR : BAR / 2
    const words = view.title === '' ? [] : view.title.split(' ')

    const total = Math.max(cells, inner - step.length - NOTE - GAP * 2)

    // The lit run of a task in progress goes to the end of its bar and back.
    const span = cells - RUN
    const lap = (await read($, beat)) % (span * 2)
    const at = lap <= span ? lap : span * 2 - lap

    // A bar with `lit` cells colored from `from` on: the gradient runs over
    // `over` cells, the whole bar for one that fills and the run for one that
    // only moves.
    const bar = (key: string, from: number, lit: number, width: number, stops: readonly string[], over = width) => (
      <Text key={key}>
        <Text color="subtle">{REST.repeat(from)}</Text>
        {Array.from({ length: lit }, (_, cell) => (
          <Text key={`${key}-${cell}`} color={mix(stops, cell / Math.max(1, over - 1))}>
            {CELL}
          </Text>
        ))}
        <Text color="subtle">{REST.repeat(width - from - lit)}</Text>
      </Text>
    )

    const { options } = one
    // The card shows the picks; the session keeps its own until it closes.
    const model = one.pick.model ?? one.model
    const effort = one.pick.effort ?? one.effort
    const isPending =
      !isSameModel(model, one.model) || (one.pick.effort !== null && effort !== one.effort)
    const picked = family(model)?.name
    const long = isLong(model)
    const models = MODELS.filter(({ name }) => options.length === 0 || options.includes(name))
    const hasLong = options.some(name => name.endsWith(LONG))

    return (
      <Box flexDirection="column">
        {beneath.type !== 'engine' && beneath}
        {hasList && (
          <Box flexDirection="column" width={inner}>
            {words.length > 0 && (
            <Text wrap="truncate-end">
              <Text color={HEADING[0]}>✳ </Text>
              {words.map((word, at) => (
                <Text key={`word-${at}`} bold color={mix(HEADING, at / Math.max(1, words.length - 1))}>
                  {`${word} `}
                </Text>
              ))}
            </Text>
            )}
            {tasks.length === 0 ? (
              <Text dimColor>working, no task list yet</Text>
            ) : (
              <Box columnGap={GAP}>
                <Text>{step}</Text>
                {bar('total', 0, Math.round(share * total), total, WARM)}
              </Box>
            )}
            {tasks.map(task => (
              <Box key={`task-${task.id}`} columnGap={GAP}>
                <Box width={Math.max(1, inner - cells - NOTE - GAP * 2)}>
                  {task.status === 'completed' ? (
                    <Text color="success">✔ </Text>
                  ) : task.status === 'in_progress' ? (
                    <Text color={WARM[1]}>● </Text>
                  ) : (
                    <Text color="inactive">○ </Text>
                  )}
                  <Text
                    bold={task.status === 'in_progress'}
                    color={task.status === 'in_progress' ? undefined : 'inactive'}
                    wrap="truncate-end"
                  >
                    {task.subject}
                  </Text>
                </Box>
                {task.status === 'completed'
                  ? bar(`bar-${task.id}`, 0, cells, cells, GREEN)
                  : task.status === 'in_progress'
                    ? bar(`bar-${task.id}`, at, RUN, cells, WARM, RUN)
                    : bar(`bar-${task.id}`, 0, 0, cells, WARM)}
                <Box width={NOTE}>
                  {task.status === 'completed' ? (
                    <Text>Done</Text>
                  ) : task.status === 'in_progress' ? (
                    <Text bold color={WARM[1]}>
                      Working
                    </Text>
                  ) : (
                    <Text color="inactive">
                      {task === upcoming ? 'Next' : 'Up next'}
                    </Text>
                  )}
                </Box>
              </Box>
            ))}
          </Box>
        )}
        {one.open && (
        <Box justifyContent="flex-end">
          <Box
            flexDirection="column"
            borderStyle="round"
            borderColor="subtle"
            paddingX={1}
            width={Math.min(CARD, e.props.bodyColumns ?? CARD)}
          >
            <Box justifyContent="space-between">
              <Text bold color="claude">
                ◆ T O O L B A R
              </Text>
              <Text dimColor>{summary(model, effort)}</Text>
            </Box>
            <Text> </Text>
            <Box flexWrap="wrap" columnGap={2}>
              <Text dimColor>MODEL </Text>
              {models.map(({ name, label }) =>
                name === picked ? (
                  <Text key={`on-${name}`} bold color="inverseText" backgroundColor="claude">
                    {` ${label} `}
                  </Text>
                ) : (
                  <Button
                    key={`model-${name}`}
                    label={label}
                    plain
                    onPress={() => pick($, { model: sized(name, long, options) })}
                  />
                ),
              )}
              {hasLong && (
                <Button
                  key="model-1m"
                  label={long ? '● 1M' : '○ 1M'}
                  plain
                  onPress={() => pick($, { model: sized(picked ?? 'opus', !long, options) })}
                />
              )}
            </Box>
            <Box flexWrap="wrap" columnGap={2}>
              <Text dimColor>EFFORT</Text>
              {EFFORTS.map(({ name, label }) =>
                name === effort ? (
                  <Text key={`on-${name}`} bold color="inverseText" backgroundColor="permission">
                    {` ${label} `}
                  </Text>
                ) : (
                  <Button
                    key={`effort-${name}`}
                    label={label}
                    plain
                    onPress={() => pick($, { effort: name })}
                  />
                ),
              )}
            </Box>
            <Text> </Text>
            <Text dimColor>SETTINGS</Text>
            <Box justifyContent="space-between">
              <Text>
                Clean View <Text dimColor> task list and summary only</Text>
              </Text>
              <Button
                key="clean"
                label={view.on ? '● On' : '○ Off'}
                variant={view.on ? 'primary' : 'secondary'}
                onPress={() => toggleClean($)}
              />
            </Box>
            <Box justifyContent="space-between">
              <Text>
                Project <Text dimColor> this project's root</Text>
              </Text>
              <Button
                key="editor"
                label="Open in VS Code"
                variant="secondary"
                onPress={() => openEditor($)}
              />
            </Box>
            <Text> </Text>
            <Box justifyContent="space-between">
              <Text dimColor>
                {isPending ? 'applies when closed' : one.model === '' ? 'model unknown' : one.model}
              </Text>
              <Button key="done" label="Done" variant="primary" onPress={() => close($)} />
            </Box>
          </Box>
        </Box>
        )}
      </Box>
    )
  })
}
