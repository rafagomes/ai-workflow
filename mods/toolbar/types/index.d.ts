export type Toolbar = {
  // The session's model as the engine names it ("claude-opus-5-5[1m]").
  model: string
  // The effort last set here or seen on a turn; null until either happens.
  effort: string | null
  // The model names `/model` takes in this build ("opus", "opus[1m]", ...).
  options: string[]
  // Whether the card is drawn above the prompt.
  open: boolean
  // What was picked in the card and not yet applied: `/model`'s argument and
  // the effort level. Applied, once each, when the card closes.
  pick: { model: string | null; effort: string | null }
}

export type Task = {
  id: string
  subject: string
  status: 'pending' | 'in_progress' | 'completed'
}

export type Clean = {
  // Clean view: the transcript shows the task list and each turn's final
  // message, and nothing of the work in between.
  on: boolean
  // True from a turn's start to its end.
  working: boolean
  // The model's task list, as its task tools last left it.
  tasks: Task[]
  // The final messages that stay drawn: the answer to what the person last
  // asked, then the latest a background task's own turn ended with.
  finals: string[]
  // A few words naming what the person's latest turn is for, written by a
  // small model: the band's heading, empty until it arrives.
  title: string
  // The turn that heading is for.
  turnId: string
}

declare module 'claude-code' {
  interface PluginState {
    // `beat` counts the ticks of the band's loading bars while a turn works: a
    // value of its own, so a tick redraws the band and not the transcript.
    toolbar: { view: Toolbar; clean: Clean; beat: number }
  }
}
