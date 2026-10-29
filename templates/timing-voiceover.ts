// La voix off, écrite par sync-voiceover : ses mots avec leur début et leur fin en millisecondes
// (le type Caption de Remotion), et les repères de chaque scène, en images depuis son début.
import voiceover from "../public/voiceover.json";

// Millisecondes en numéro d'image.
export const msToFrame = (ms: number, fps: number) => Math.round((ms * fps) / 1000);

export const words = voiceover.words;

// Image, depuis le début de la scène, de son repère n (0 pour le premier, dans l'ordre du storyboard).
export const cueFrame = (scene: string, n: number): number => {
  const cue = (voiceover.cues as Record<string, { frame: number }[]>)[scene]?.[n];
  if (!cue) throw new Error(`Repère ${n} de ${scene} absent de public/voiceover.json : relancer /plugin-motion:sync-voiceover.`);
  return cue.frame;
};
