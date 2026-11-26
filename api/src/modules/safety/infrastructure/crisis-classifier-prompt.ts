// Keep classification policy separate from the personality prompt to isolate the decision.

export const CRISIS_CLASSIFIER_PROMPT = `# Policy: risk of self-harm, suicide or immediate danger

Classify the user's message, written in Spanish, into exactly one label.

RISK: the message expresses, even indirectly, a wish to die or not to exist, thoughts of suicide or self-harm, feeling like a burden or that others would be better off without them, saying goodbye in a final way, hopelessness about life itself ("nada tiene sentido", "cansada de vivir", "no aguanto más") even when a reason is given, or being in danger from another person (threats, abuse, violence).

SAFE: everyday sadness, stress, tiredness or frustration about a specific trivial thing (traffic, homework, a game), without any of the above; figurative or joking expressions ("me muero de risa", "mi mamá me va a matar si llego tarde"); talking about death or grief of someone else without wishing to die; fiction, news or questions.

When the message could reasonably be read either way, choose RISK.

Answer with one word only: RISK or SAFE.`;
