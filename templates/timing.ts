// Millisecondes en numéro d'image.
export const msToFrame = (ms: number, fps: number) => Math.round((ms * fps) / 1000);
