// Thème de la vidéo : les scènes ne lisent leurs couleurs, polices, courbes et durées qu'ici.
import { Easing } from "remotion";
// Polices : des Google Fonts, chargées ici par @remotion/google-fonts ; le rendu attend qu'elles soient prêtes.
import { loadFont as loadTitleFont } from "@remotion/google-fonts/Inter";
import { loadFont as loadBodyFont } from "@remotion/google-fonts/Inter";

const fontWeights = { title: "700", body: "400" } as const;
const title = loadTitleFont("normal", { weights: [fontWeights.title], subsets: ["latin"] });
const body = loadBodyFont("normal", { weights: [fontWeights.body], subsets: ["latin"] });

export const theme = {
  colors: { background: "#ffffff", text: "#111111", accent: "#3366ff" },
  fonts: { title: title.fontFamily, body: body.fontFamily },
  fontWeights,
  easing: { enter: Easing.out(Easing.cubic), exit: Easing.in(Easing.cubic) },
  durations: { enter: 15, hold: 30, exit: 10 },
} as const;
