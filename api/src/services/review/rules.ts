// What a reply from marlix must never contain (S2-4), following the limits of
// the personality prompt (docs/system-prompt.md). Phrases are in Spanish and
// match like the crisis signals: whole words, `*` for any ending. A phrase
// right after "no" does not count, so "no soy tu terapeuta" passes.

export type ReviewRule =
  | 'clinical_advice'
  | 'diagnosis'
  | 'professional_claim'
  | 'discourages_help'
  | 'dependence'
  | 'harmful_information';

// Checked in this order, most serious first; a sentence reports the first rule it breaks.
export const REVIEW_RULES: Readonly<Record<ReviewRule, readonly string[]>> = {
  harmful_information: [
    'dosis letal',
    'cantidad letal',
    'metodos de suicidio',
    'formas de suicid*',
  ],
  // Medication and doses: only a professional can recommend them.
  clinical_advice: [
    'antidepresiv*',
    'ansiolitic*',
    'benzodiacepin*',
    'sertralina',
    'fluoxetina',
    'escitalopram',
    'paroxetina',
    'clonazepam',
    'alprazolam',
    'diazepam',
    'lorazepam',
    'zolpidem',
    'quetiapina',
    'miligramo*',
    'mg',
    'dosis',
    'te receto',
    'te recomiendo tomar',
    'deberias tomar',
    'tomate una pastilla',
    'toma una pastilla',
  ],
  diagnosis: [
    'tenes depresion',
    'tienes depresion',
    'tenes ansiedad',
    'tienes ansiedad',
    'tenes un trastorno',
    'tienes un trastorno',
    'sufris de',
    'sufres de',
    'sos bipolar',
    'eres bipolar',
    'te diagnostico',
    'mi diagnostico',
    'tu diagnostico es',
  ],
  professional_claim: [
    'soy tu psicologo',
    'soy tu psicologa',
    'soy tu terapeuta',
    'soy tu medico',
    'soy tu doctor',
    'como tu psicologo',
    'como tu psicologa',
    'como tu terapeuta',
    'como tu medico',
  ],
  discourages_help: [
    'no necesitas un psicologo',
    'no necesitas una psicologa',
    'no necesitas terapia',
    'no necesitas ayuda profesional',
    'no vayas al psicologo',
    'no vayas al medico',
    'no llames al',
    'no hace falta llamar',
  ],
  dependence: [
    'solo me necesitas a mi',
    'solo me tenes a mi',
    'solo me tienes a mi',
    'yo te entiendo mejor que nadie',
    'no necesitas a nadie mas',
    'no hables con nadie mas',
    'olvidate de los demas',
  ],
};
