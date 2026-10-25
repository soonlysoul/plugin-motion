// Thème de la vidéo : les scènes ne lisent leurs couleurs, polices, courbes et durées qu'ici.
import { Easing } from "remotion";

export const theme = {
  colors: { background: "#ffffff", text: "#111111", accent: "#3366ff" },
  fonts: { title: "Inter", body: "Inter" },
  easing: { enter: Easing.out(Easing.cubic), exit: Easing.in(Easing.cubic) },
  durations: { enter: 15, hold: 30, exit: 10 },
} as const;
