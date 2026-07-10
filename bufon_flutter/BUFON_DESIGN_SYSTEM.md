# BUFÓN — Sistema de Diseño

**Versión 1.1 · Revisión crítica**
Este documento es la biblia de diseño de Bufón. No es una guía de estilo decorativa: es la referencia que debe sobrevivir rediseños de pantallas individuales, cambios de equipo, y al menos dos años de crecimiento del producto. Cuando una decisión de UI esté en duda, la respuesta debe poder derivarse de este documento sin tener que preguntarle a nadie.

**Changelog v1.0 → v1.1:** la v1.0 definía reglas visuales sin haber definido primero qué emoción debían servir — construía la gramática antes que el idioma. Esta revisión agrega la base emocional (`THE BUFÓN FEELING`, `EMOTIONAL JOURNEY`), formaliza una física de marca propia (`BRAND PHYSICS`, `RHYTHM SYSTEM`) en vez de heredar metáforas de Material/Apple sin cuestionarlas, resuelve tres contradicciones internas (Butter como "huella cromática" vs. su ausencia real durante el 70% del tiempo de juego; Lavender asignado simultáneamente a "misterio de votación" y a "monetización premium"; el modelo de "elevación por niveles" copiado de Material a pesar del objetivo explícito de no parecer Material), señala dos decisiones genéricas que cualquier app de fiesta ya usa (la terna tipográfica Fredoka/Baloo/Poppins, el set de íconos Phosphor) y las reemplaza por un criterio de selección más exigente, y desarrolla el lenguaje sonoro más allá de dos palabras ("madera", "campanas") hacia un sistema de materiales completo. Los capítulos que ya funcionaban (1, 2, 5, 7, 9-11, 13-18, 21-30, 32-33, 35) se mantienen sin cambios de fondo — solo referencias cruzadas nuevas donde corresponde.

Este sistema **no reemplaza** el trabajo visual que ya existe en el código — lo evoluciona. Donde algo ya construido es bueno (la mecánica de `ConfettiWidget`, el patrón de scale-press de `AnimatedPrimaryButton`, la escala de espaciado de `AppSpacing`, el timing del reveal en dos tiempos), este documento lo formaliza y le da un lenguaje de marca real. Donde algo contradice la identidad (la paleta actual "casino nocturno" de `AppColors`, la ausencia total de modo claro, el uso de iconografía Material genérica), este documento lo señala explícitamente y traza el camino de migración.

---

## Auditoría de partida: qué existe hoy

Antes de diseñar nada, esto es lo que hay en el repo, verificado archivo por archivo:

| Área | Archivo | Estado | Veredicto |
|---|---|---|---|
| Colores | `lib/core/theme/app_colors.dart` | Tema oscuro "casino": fondo `#111111`, primario rojo `#E94560`, acento cian `#00D9FF`, dorado `#FFD700`, cards azul-violeta `#1A1A2E`/`#16213E` | **Reemplazar** — cero relación con el isotipo |
| Theme | `lib/core/theme/app_theme.dart` | `ThemeData` con `useMaterial3: true`, bien estructurado, mapea tokens a roles de Material correctamente | **Preservar la estructura**, recablear los tokens |
| Tipografía | `lib/core/theme/app_typography.dart` | Escala numérica sólida (12/14/16/20/24/28/32/48), pero fuente de sistema (Roboto/San Francisco) sin personalidad | **Preservar la escala, cambiar la fuente** |
| Espaciado | `lib/core/theme/app_spacing.dart` | Escala 4/8/16/24/32/48/64, `cardRadius: 20`, `buttonRadius: 16`, `buttonHeight: 56` | **Preservar íntegro** — es una base correcta |
| Botón animado | `lib/presentation/widgets/animated_primary_button.dart` | Scale-press (1.0→0.95, 100ms, easeInOut) + haptic + sonido en cada tap | **Preservar el mecanismo**, recablear color/gradiente |
| Tarjeta de juego | `lib/presentation/widgets/game_card.dart` | Scale-press (0.97) + pulso al seleccionar (1.03) + haptic medium | **Preservar el mecanismo** |
| Confetti | `lib/presentation/widgets/confetti_widget.dart` | 50 partículas, gravedad simulada, rotación, `CustomPainter` — mecánica sólida | **Preservar la mecánica**, recablear paleta de colores |
| Timer | `lib/presentation/widgets/timer_widget.dart` | Arco circular custom-pintado + pulso + copy que escala urgencia + haptic en los últimos 5s | **Preservar íntegro**, recablear color |
| Transiciones | `lib/presentation/navigation/page_transitions.dart` | Fade + slide, 250ms, `easeInOut` — solo usado en `presentation/screens/`, no en el loop principal | **Preservar y extender a todo el loop** |
| Haptics | `lib/services/haptic_service.dart` | Vocabulario completo ya definido (light/medium/heavy/selection/celebration) | **Preservar íntegro**, formalizar el mapeo por momento |
| Sonido | `lib/services/sound_service.dart` | Solo 2 `SystemSound` del OS (click, alert) — no hay biblioteca de audio propia | **Honesto: no existe todavía.** Diseñar la dirección, construir después |
| Modo claro | — | **No existe.** `scaffoldBackgroundColor` está fijado globalmente al tema oscuro | **Construir desde cero** |
| Iconografía | dispersa en screens | `Icons.sports_esports`, `Icons.timer_outlined`, etc. — Material default sin tratamiento | **Reemplazar por sistema propio** |
| Home / Lobby | `lib/screens/home_screen.dart`, `lobby_screen.dart` | Cero uso de `AppColors`/`AppTypography`, `Colors.blue.shade50`, `Colors.grey.shade200` hardcodeados | **Migrar primero** — es la brecha más grande |

No se destruye ningún mecanismo que ya funciona. Se le da un lenguaje de marca a mecanismos que hoy son visualmente huérfanos.

---

## THE BUFÓN FEELING

*Capítulo fundacional — todo lo demás en este documento existe para servir esto.*

**¿Qué debe recordar una persona tres días después de haber jugado Bufón?**

No debe recordar una pantalla. No debe recordar un color. Debe recordar **el momento exacto en que su grupo de amigos se quedó completamente en silencio leyendo una respuesta, y luego explotó en risa al mismo tiempo.** Bufón no vende un juego — vende ese segundo específico, y todo lo demás (la app, las reglas, el arte) es la maquinaria que lo hace posible ocho veces por noche.

La huella emocional de Bufón tiene tres capas, y las tres deben estar presentes o el juego se siente incompleto:

**1. Complicidad expuesta.** Bufón funciona porque cada respuesta es una pequeña confesión — de humor, de honestidad, de qué tan bien conoces a tus amigos. El recuerdo no es "gané" o "perdí"; es "no puedo creer que Juan haya escrito eso" o "no puedo creer que adivinaran que fui yo". Es el placer de ser visto por tu grupo cercano y sobrevivir a eso, incluso disfrutarlo.

**2. Tensión que se gana el derecho a soltarse.** El recuerdo memorable nunca es la broma sola — es la broma DESPUÉS de un silencio construido a propósito (leyendo, votando, esperando el reveal). Sin la contención previa, la risa es más débil. Bufón le debe al jugador ese silencio; es lo que hace que el estallido valga la pena recordarlo.

**3. Pertenecer, no ganar.** El ganador de la noche se recuerda, pero lo que realmente queda es "qué buena estuvo esa noche con este grupo específico" — no un marcador. Un juego que se recuerda solo por quién ganó fracasó en construir el sentimiento correcto; un juego que se recuerda por LO QUE PASÓ tuvo éxito.

**La frase que resume todo el sistema:** *Bufón no hace reír a la gente. Bufón crea las condiciones para que la gente se haga reír entre sí, y luego se sale del camino.*

Cada decisión de este documento — cada color, cada milisegundo de animación, cada silencio prescrito — existe para proteger esos tres segundos de complicidad expuesta. Si una decisión de diseño no puede justificarse en función de esto, es decoración, no sistema.

---

## EMOTIONAL JOURNEY

*Cómo se siente una sesión completa, de principio a fin. Cada etapa está diseñada como una unidad — emoción, intensidad, color, cuerpo (haptics), oído (sonido) y ritmo trabajando juntos, nunca uno sin los otros.*

| # | Etapa | Emoción dominante | Intensidad (1-10) | Duración aprox. | Color dominante | Haptics | Sonido | Ritmo | Velocidad visual | Movimiento | Humor | Tensión social |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | **Apertura** (abrir la app) | Curiosidad | 2 | 2-4s | Butter | Ninguno | Ninguno | Lento, sin prisa | Lenta | Mínimo — un elemento respirando | Bajo | Ninguna |
| 2 | **Invitación** (crear/unirse a sala) | Expectativa | 3 | 15-30s | Butter → Paper | `lightImpact` en cada tap | Tap seco | Constante, sin picos | Media | Entrada de cada jugador con `Arrive` | Bajo-medio (primeras bromas del grupo) | Baja |
| 3 | **Reunión** (lobby, esperando jugadores) | Complicidad naciente | 4 | 30-90s (variable, social) | Butter | `mediumImpact` cuando entra cada jugador | Campanilla breve por jugador nuevo | Se acelera levemente con cada jugador que llega | Media | Lista de jugadores creciendo | Medio (el grupo ya está bromeando entre sí, no en la app) | Baja |
| 4 | **Creatividad bajo presión** (responder) | Ansiedad divertida | 7 | 45-90s | Graphite + Sky | `lightImpact` en los últimos 5s | Tic-tac sutil que se intensifica | Acelerando — el único momento de aceleración sostenida | Media→rápida | Timer pulsando, contador de "N respondieron" subiendo | Alto (interno, el jugador se está riendo de su propia respuesta) | Media — nadie ve lo que escribes, pero sabes que lo van a leer |
| 5 | **Complicidad expuesta** (votar) | Suspenso cómplice | 6 | 20-40s | Graphite + Lavender | `mediumImpact` al votar | Clic de "sello" | Silencioso, sin picos — el ritmo se detiene a propósito | Lenta, deliberada | Tarjetas quietas, sin urgencia visual | Muy alto (leyendo las respuestas de todos) | Alta — estás juzgando en secreto a tus amigos |
| 6 | **El silencio** (transición votación→reveal) | Contención | 5 | 2-3s | Graphite oscureciéndose | Ninguno — silencio también háptico | Ninguno — silencio también sonoro | Pausa total, deliberada | Casi estática | Casi nada se mueve | Ninguno — es el momento de aguantar la respiración | Máxima — el pico de tensión de toda la ronda |
| 7 | **Explosión** (reveal, dos etapas) | Sorpresa → deleite | 9 | 1.5-2s | Graphite + Butter | `lightImpact` (etapa 1) → `celebration()` (etapa 2) | Redoble → fanfarria corta | El estallido — toda la energía contenida se libera de golpe | Muy rápida | Máximo movimiento simultáneo (texto, ícono, confetti) | Máximo — la broma aterriza | Se disuelve — el secreto ya se reveló |
| 8 | **Celebración** (ganador de ronda) | Euforia compartida | 8 | 3s | Mint + confetti | `celebration()` | Fanfarria | Sostenido, sin acelerar más | Rápida pero estable | Confetti cayendo, spotlight | Alto — todos reaccionan a la vez | Ninguna — el grupo celebra junto, no compite |
| 9 | **Respiro** (antes de la siguiente ronda) | Anticipación calmada | 3 | 3-5s | Graphite atenuado | Ninguno | Ninguno | Desacelera deliberadamente | Lenta | Mínimo | Medio (comentarios post-ronda del grupo) | Baja |
| 10 | **Repetición con memoria** (rondas 2-N) | Todo lo anterior, pero cada vuelta con más historia acumulada entre el grupo | Igual que 4-9, +1 de intensidad por ronda | — | — | Igual, ligeramente más marcado | Igual | El ciclo se repite pero el "piso" de energía sube (ver `RHYTHM SYSTEM`) | — | — | Sube — cada ronda el grupo tiene más contexto para reírse | Sube — más rondas, más se conocen las respuestas de cada quien |
| 11 | **El clímax** (ganador de la noche) | Euforia + cierre narrativo | 10 | 5-8s | Butter/Graphite ceremonial + confetti extendido | `celebration()` repetida por cada stat revelada | Fanfarria extendida | El pico absoluto de todo el journey — nunca se vuelve a tocar este nivel | Máxima | Máximo movimiento sostenido de toda la sesión | Máximo, pero ahora es celebración de grupo, no de chiste individual | Se disuelve por completo — es un cierre, no una competencia |
| 12 | **Cierre** ("una más") | Satisfacción + deseo de repetir | 6 (bajando desde 10, pero no hasta 0) | 5-10s | Butter, modo claro | `lightImpact` en el CTA de revancha | Ninguno | Desacelera pero deja un remanente de energía — nunca cae a cero | Media | Botón de "otra ronda" con `Pulse` sutil, invitando | Medio (última broma del cierre) | Ninguna — el objetivo es que quieran repetir, no que se vayan |

**La regla narrativa que conecta todo:** la intensidad NUNCA sube en línea recta — sube en dientes de sierra (cada ronda es un ciclo completo de tensión-liberación), pero el **piso** de cada diente es más alto que el anterior, hasta el pico final. Esto se desarrolla completo en `RHYTHM SYSTEM`. Si dos etapas consecutivas tienen la misma intensidad, algo del diseño está aplanando el journey y hay que revisarlo.

---

## Capítulo 0 — ¿Qué hace un screenshot (o un video) de Bufón reconocible sin el logo?

Esta es la pregunta que organiza todo el sistema visual. Si alguien quita el isotipo de una captura de pantalla de Bufón y la mezcla con capturas de otros diez party games, ¿qué la delata? Once respuestas, no solo color y forma — la primera versión de este capítulo se quedó corta al hablar solo de lo visual; reconocibilidad es multisensorial.

**Composición.** Una zona de protagonismo absoluto ocupando 40-60% del alto de pantalla; todo lo demás comprimido a franjas delgadas en los bordes. Nunca tarjetas de igual peso repartidas uniformemente.

**Color — con una tensión que hay que admitir.** Butter es la huella cromática de la marca, pero la mayoría del tiempo de juego real (Responder, Votar, buena parte del Reveal) vive en Graphite, no en Butter — ver Capítulo 33. Esto no es una contradicción a esconder, es una decisión: **Butter es el color de los umbrales (antes y después de jugar), Graphite es el color de estar jugando.** Un screenshot de Lobby o del Ganador debe ser inconfundiblemente amarillo; un screenshot de una ronda en vivo debe ser inconfundiblemente oscuro con UN acento de color puntual (Sky o Lavender según la fase). Ambos son reconocibles como Bufón por razones distintas — el error sería querer que Butter dominara también las pantallas de juego en vivo, diluyendo el contraste emocional entre "estamos a punto de jugar" y "estamos jugando".

**Ritmo.** Pausa deliberada, luego estallido — nunca energía plana constante. Ver `EMOTIONAL JOURNEY` y `RHYTHM SYSTEM`.

**Tipografía.** Números y palabras clave en un display bold, redondeado, tracking negativo, desproporcionadamente grandes — igual que la "O" domina "BUFÓN".

**Motion.** Todo llega comprimido y se libera con un leve rebote (ver `BRAND PHYSICS`), nunca con un fade lineal de Material.

**Geometría.** Esquinas redondeadas extremas, cero esquinas rectas en UI interactiva, iconografía sólida y gruesa nunca outline delgado.

**Microinteracciones.** Cada tap relevante dispara al menos dos señales simultáneas — nunca una sola.

**Sonido y haptics, incluso con el sonido apagado.** Un video de Bufón sin audio debe seguir sintiéndose "sonoro" por el ritmo visual que imita percusión (ver `RHYTHM SYSTEM`); con audio, el material sonoro de cartón/madera/sello (Capítulo 20) es tan distintivo como el color — ningún otro party game suena a "sello de cera golpeando papel" en su reveal.

**Timing.** El silencio de 2-3 segundos antes del reveal (etapa 6 del `EMOTIONAL JOURNEY`) es, por sí solo, un elemento de marca: ninguna otra app de fiesta se atreve a no hacer nada durante tres segundos completos.

**Tono.** El copy nunca es neutro de producto; siempre tiene una opinión ligera, cómplice, nunca cruel.

**La prueba de fuego:** si tapas el logo, silencias el sonido, y quitas el copy, y la captura TODAVÍA se identifica por su composición, su geometría y su ritmo de movimiento — el sistema funcionó. Si necesitas leer texto o ver el amarillo para reconocerlo, todavía depende de decoración, no de sistema.

---

## Capítulo 1 — Principios de diseño

1. **El bufón nunca es cruel, siempre es cómplice.** La irreverencia de Bufón se ríe CON el jugador, nunca de él. Ningún estado de error, ninguna derrota, ningún copy debe sentirse como un castigo.
2. **Una pantalla, una protagonista.** Cada pantalla tiene exactamente un elemento que domina la jerarquía visual. Si dos elementos compiten por atención, el diseño está roto.
3. **El silencio es parte del ritmo.** No todo necesita movimiento o color. Los momentos de espera (lobby, esperando votos) deben sentirse deliberadamente calmos para que el estallido del reveal tenga contraste real.
4. **Construir para la mesa, no para el escritorio.** Cada decisión se evalúa pensando en un teléfono en el centro de una mesa, con 4-8 personas mirando por encima del hombro de quien lo sostiene — texto grande, contraste alto, nada que dependa de ver de cerca.
5. **La marca vive en la geometría, no en el logo.** El isotipo puede estar ausente de una pantalla; el redondeo, el contraste, la tipografía y el motion no pueden.
6. **Evolucionar, no reescribir.** Todo mecanismo de interacción que ya funciona en el código (scale-press, pulso, confetti, reveal en dos tiempos) se conserva y se re-viste, no se reinventa.
7. **Compartible por diseño, no por accidente.** Cada pantalla de alto valor emocional (ganador, resultado de ronda) se diseña asumiendo que terminará como captura de pantalla en un chat de WhatsApp.
8. **Accesible no es opcional.** Ningún patrón visual depende de un solo canal sensorial (color solo, sonido solo, haptic solo).

---

## Capítulo 2 — Personalidad de marca

### El análisis del isotipo

La cara del bufón está reducida a lo mínimo posible sin perder calidez: ojos cerrados en forma de arco feliz (no ojos abiertos, no cejas — la expresión es de placer/complicidad, no de sorpresa ni de alerta), una nariz redonda sólida tipo payaso, una sonrisa amplia de trazo grueso con las comisuras hacia arriba, orejas como protuberancias redondeadas simples, y un gorro de bufón de dos picos que termina en dos círculos con un detalle de "ojo de cerradura" recortado — no la campana tradicional del bufón, sino algo más parecido a un candado o mirilla. Esto es una decisión de diseño deliberada y es una pista narrativa fuerte: **Bufón guarda secretos hasta que decide revelarlos**, que es literalmente el mecanismo central del juego (nadie ve las respuestas ni los votos hasta el reveal). Ese detalle del "ojo de cerradura" debería ser el germen de todo el lenguaje de "misterio antes de la revelación" que usamos en Votación y Reveal.

Todo el isotipo es una sola tinta sólida, sin degradados, sin sombras, sin texturas — geometría pura de alto contraste sobre Butter. Es un lenguaje de **cartel serigrafiado**, no de icono de app tech.

### El descubrimiento del logotipo

La palabra "BUFON" no acompaña al isotipo — **lo integra como letra**. La "O" central de la palabra ES la cara del bufón; el gorro se convierte en la parte superior de esa letra. Esto es el dato de diseño más importante de toda la identidad: Bufón no es una marca con un ícono al lado del nombre, es una marca donde **el personaje y la tipografía son la misma forma**. Ningún sistema de diseño derivado de este logo puede tratar "tipografía" e "iconografía/ilustración" como capítulos separados y sin relación — deben compartir ADN geométrico (mismo grosor de trazo, mismos radios de esquina, misma calidez).

La tipografía del logotipo es un display geométrico ultra-bold, con terminaciones muy redondeadas, altura de x muy alta, y letras casi sin espaciado entre sí — cada letra se siente como una pieza sólida de un rompecabezas, no como caracteres independientes. Esto informa directamente el Capítulo 6.

### Arquetipo de marca

Bufón es **El Bufón de la corte**: el único personaje que puede decirle la verdad al rey sin ser castigado, porque lo hace con humor. Tiene permiso social para la irreverencia porque la envuelve en ingenio, no en crueldad. No es un payaso de circo (infantil, ruidoso, torpe) ni un comediante stand-up cínico (afilado, agresivo). Es cómplice, no espectáculo.

**Bufón ES:** ingenioso, cómplice, seguro de sí mismo, cálido, un poco travieso, generoso con el protagonismo ajeno (celebra al ganador con la misma energía con la que se burla del perdedor).

**Bufón NO ES:** infantil, ruidoso sin propósito, cruel, sarcástico-frío, corporativo-amigable ("¡Hola! 😊"), un juego de trivia serio.

### Voz

Segunda persona, presente, mexicano-neutro sin regionalismos que no viajen. Frases cortas con un giro al final ("No presionamos, pero sí estamos juzgando"). El copy existente en `game_copy.dart` ya acierta este tono — el problema no es la voz, es su cobertura: hoy vive solo en 3-4 pantallas y el resto usa copy neutro de formulario. Este documento exige que la voz sea universal, sin excepciones, incluyendo mensajes de error y validación.

---

## Capítulo 3 — Lenguaje visual

*Nota de la revisión v1.1: este capítulo y el Capítulo 0 decían casi lo mismo con distintas palabras (alto contraste, geometría redondeada, composición de cartel aparecían en ambos). Capítulo 0 responde "¿qué lo hace reconocible?" desde la experiencia del que MIRA una captura; este capítulo responde "¿qué reglas formales lo producen?" desde la perspectiva del que CONSTRUYE — son las mismas cuatro leyes, pero aquí son prescriptivas y verificables, no descriptivas.*

Cuatro leyes formales, todas derivadas directamente del isotipo y verificables en cualquier PR:

**1. Plano por default, degradado por excepción.** Regla verificable: un `grep` de `LinearGradient` en `lib/` debe devolver como máximo 2-3 resultados (los momentos ceremoniales del Capítulo 8), nunca uno por botón como hoy (`primaryGradient`, `goldGradient` en cada `AnimatedPrimaryButton`/`GameCard` seleccionado).

**2. Sin zona de contraste medio.** Regla verificable: ningún `Color` de fondo de contenido puede tener una luminosidad entre el 15% y el 85% — o es claramente oscuro (Graphite) o claramente claro (Paper/Butter). El `#1A1A2E` actual cae exactamente en esa zona prohibida.

**3. Radio trazable al isotipo.** Regla verificable: todo `borderRadius` en un componente interactivo debe existir en la escala del Capítulo 10 — cero valores inventados ad-hoc (`BorderRadius.circular(4)`, `8`, `10` sueltos).

**4. Un elemento gigante, todo lo demás diminuto.** Regla verificable, la más difícil de automatizar pero la más importante: en cualquier pantalla, debe existir un elemento cuyo tamaño tipográfico o de área sea al menos 2.5× el segundo elemento más grande. Si dos elementos compiten en tamaño similar, la jerarquía falló — esta es una revisión de diseño manual, no de linter, pero debe hacerse en cada PR de UI igual que se corre `flutter analyze`.

---

## Capítulo 4 — Uso emocional del color

Cada color de la paleta tiene un rol emocional fijo. Esto no es decoración — es la razón por la que un jugador debe poder saber en qué fase del juego está con el sonido apagado y sin leer texto, solo por el color dominante de la pantalla.

| Color | Emoción | Cuándo aparece |
|---|---|---|
| **Butter** | Anticipación alegre, "algo bueno va a pasar" | Lobby, entrada, momentos de invitación a jugar |
| **Ink** | Autoridad tranquila, foco, "esto importa" | Texto sobre Butter/Paper, estructura, jerarquía |
| **Paper** | Calma, claridad, pausa social | Pantallas de configuración/perfil, momentos de lectura |
| **Graphite** | Intimidad, foco cinematográfico, "todos están mirando lo mismo" | Responder, votar — el juego "en vivo" |
| **Mint** | Alivio, validación, "lo lograste" | Confirmaciones, éxito, ganador |
| **Coral** | Tensión, urgencia, "se acaba el tiempo" | Timer en peligro, errores, límites alcanzados |
| **Sky** | Energía social, "aquí está pasando algo" | Presencia en línea, actividad de otros jugadores, respuestas llegando |
| **Lavender** | Misterio, expectativa antes del veredicto | Votación (nadie sabe aún quién ganará), momento previo al reveal |

Regla dura: **un color emocional por pantalla como protagonista.** Butter y Lavender nunca compiten por dominancia en la misma vista — si Lobby es Butter, Votación es Lavender, nunca ambos a la vez en la misma composición salvo como acento puntual.

**Conflicto detectado y resuelto en v1.1:** la dirección visual original del producto asignaba Lavender tanto a "votación/misterio" como a "premium/monetización" — dos registros emocionales incompatibles compitiendo por el mismo color (¿Lavender significa "estoy juzgando en secreto" o "esto cuesta dinero"?). Se resuelve así: **Lavender queda reservado exclusivamente al misterio de juego** (Votación, el instante previo al reveal). La Paywall/Night Pass usa Ink sobre Paper con Butter como único acento de acción (ver Capítulo 33) — la monetización no necesita ni merece un color emocional propio; pedir dinero con "misterio" sería, además, manipulador (ver Capítulo 34). Si en el futuro se necesita un color exclusivo para premium/temporadas, debe ser una decisión nueva y explícita, no una reutilización de Lavender.

---

## Capítulo 5 — Color System

### Refinamientos propuestos a la paleta base (con justificación)

La paleta de 8 colores es una base sólida. Se proponen 3 ajustes, cada uno justificado:

1. **Retirar `gold`/`amber` como color independiente; Butter asume ese rol.** El tema actual tiene `gold #FFD700` para celebración/premium, casi idéntico en temperatura a Butter `#F8EE67`. Tener dos amarillos casi iguales es redundancia sin beneficio — Butter ya es el color de "algo especial está pasando" del propio logo. Se retira `gold` del sistema.
2. **Graphite recibe un sesgo cálido, no gris neutro.** Un gris frío (`#2A2A2A` con tinte azulado, como el actual `#1A1A2E`) rompe la relación con Butter. Se ajusta Graphite a un negro-marrón muy sutil (`#242320`, +2% de calidez sobre el `#2A2A2A` propuesto) para que el modo oscuro se sienta como "la misma marca, luz apagada", no como una app distinta.
3. **Cada color necesita una rampa de 3 pasos (tint/base/shade), no un solo valor.** Un solo hex por color es insuficiente para fondos sutiles, bordes y estados de press/disabled. Se define la rampa abajo.

### Tabla de color completa

| Token | Base | Tint (fondo sutil, 10% opacidad efectiva) | Shade (texto/borde sobre su propio fondo) |
|---|---|---|---|
| `butter` | `#F8EE67` | `#FDFBE8` | `#D9C92A` |
| `ink` | `#191919` | `#8A8578` (ink-soft, no un gris puro) | `#000000` |
| `paper` | `#FAFAF7` | `#FFFFFF` | `#E4DFCF` (paper-line, bordes sobre Paper) |
| `graphite` | `#242320` | `#3A382F` (graphite+1, elevación) | `#151410` |
| `mint` | `#63D6A5` | `#E4F6EE` | `#1F9C6E` |
| `coral` | `#FF7A6A` | `#FDE9E4` | `#E85A46` |
| `sky` | `#6BC8FF` | `#E4F3FC` | `#1C7FB8` |
| `lavender` | `#9C8CFF` | `#EEEAFB` | `#6F5BD6` |

### Mapeo de migración (de `AppColors` actual a los tokens nuevos)

| Token actual | Valor actual | Token nuevo |
|---|---|---|
| `background` | `#111111` | `graphite` (modo oscuro) / `paper` (modo claro) |
| `primary` | `#E94560` | `coral` (tensión/error) — **ya no es el color de marca dominante** |
| `accent` | `#00D9FF` | `sky` |
| `gold`/`goldDark` | `#FFD700`/`#FFB700` | `butter` (retirado como color separado) |
| `success` | `#4CAF50` | `mint` |
| `error` | `#E94560` | `coral` |
| `surface`/`surfaceDark` | `#1A1A2E`/`#16213E` | `graphite` / `graphite+1` |
| `textPrimary` | `#FFFFFF` | `paper` (sobre Graphite) / `ink` (sobre Paper o Butter) |

### Reglas de uso

- Texto sobre Butter: siempre `ink`, nunca blanco (el logo nunca usa blanco sobre Butter).
- Texto sobre Graphite: `paper`, nunca `ink` puro invertido (evitar el efecto "negativo fotográfico").
- Nunca combinar `coral` y `mint` en el mismo componente (rompe la jerarquía semántica éxito/error).
- Los degradados quedan reservados a Capítulo 8; el color plano es el default.

**Nota de escalabilidad (v1.1):** la tabla de arriba fija 24 valores hex a mano (8 colores × 3 pasos). Eso es correcto como *resultado* pero insuficiente como *sistema* — si en Fase 3I o más adelante se necesita un color nuevo (una temporada con su propio acento, por ejemplo), nadie debería "inventar" un hex a ojo. La fórmula de generación: `tint = base con luminosidad HSL llevada a 95%, saturación reducida 40%`; `shade = base con luminosidad HSL reducida 25%, saturación aumentada 10%`. Cualquier color nuevo que entre al sistema se deriva con esta fórmula, no por selección visual manual — así la rampa de un color nuevo es predecible y consistente con las ocho ya definidas.

---

## Capítulo 6 — Typography System

### Dirección tipográfica

**Autocrítica de v1.0 (dejarla registrada, no borrarla):** la recomendación original era Fredoka, Baloo 2 o Poppins ExtraBold. Es la elección segura — y por eso mismo está mal. Esas tres fuentes son, hoy, el uniforme visual de facto de cualquier app "amigable y redondeada" (edtech infantil, apps de hábitos, la mitad de los party games del Play Store). Adoptarlas no evolucionaría la identidad del logotipo — la disolvería en un océano de apps que ya se ven así. El logotipo de Bufón tiene un rasgo que ninguna de esas tres fuentes tiene: las letras casi se TOCAN entre sí, como piezas de un sello de goma tallado en un solo bloque, no como caracteres independientes espaciados con cuidado tipográfico convencional. Ese "casi-tocarse" es más cercano al lenguaje de un sello de caucho o una plantilla de esténcil que al de una interfaz amigable — es más Panic/Playdate que Duolingo.

**Criterio de selección revisado (más exigente que "redondeada y bold"):** la tipografía de marca debe tener (1) terminaciones redondeadas — esto sí se mantiene, es real en el logotipo —, (2) un tracking naturalmente apretado incluso en su versión de UI, no solo en el lockup, y (3) cierta irregularidad de carácter en sus formas (una "O" no perfectamente circular, una "U" con una asimetría sutil) que la aleje del vocabulario "geométrico perfecto" que comparten Poppins/Century Gothic/Futura y sus derivados — ese vocabulario es exactamente el que un crítico de Panic Inc. señalaría como "la opción que elegiría cualquiera". Direcciones a evaluar en dispositivo antes de fijar: familias tipo **stencil/sello suavizado** (ej. una variable custom-cut, o explorar **Recoleta**/**Cooper-adjacent** en peso bold para el carácter editorial-cartel, no la ruta "friendly-app" default) para Display, reservando la decisión final a una prueba lado a lado contra el logotipo real, no a la familiaridad de la fuente.
- **Body / UI:** aquí sí se prioriza neutralidad sobre carácter — es texto funcional, no de marca. **Plus Jakarta Sans** o **Work Sans** siguen siendo razonables por legibilidad y soporte de números tabulares, con la salvedad de que esta elección importa mucho menos que la de Display.
- **Números tabulares:** activar `fontFeatures: [FontFeature.tabularFigures()]` en timer, puntajes y contadores — hoy `AppTypography.display`/`displayGold` no lo hacen, y un timer que "baila" de ancho cada segundo rompe la sensación premium.

### Escala (se preserva la existente — ya es correcta)

| Token | Tamaño actual | Preservar |
|---|---|---|
| `caption` | 12 | Sí |
| `body2` | 14 | Sí |
| `body1` | 16 / `button` 16 | Sí |
| `h4` | 20 | Sí |
| `h3` | 24 | Sí |
| `h2` | 28 | Sí |
| `h1` | 32 | Sí |
| `display` | 48 | Sí — y se convierte en el tamaño reservado para: código de sala, conteo del timer en pantalla completa, puntaje final |

Regla nueva: `letterSpacing` negativo (-0.5 a -1) se aplica SOLO a `display`/`h1`/`h2` (headlines grandes, imitando el tracking apretado del logotipo); el resto mantiene espaciado neutro para legibilidad.

---

## Capítulo 7 — Spacing System

La escala de `AppSpacing` (4/8/16/24/32/48/64) se preserva íntegra — es matemáticamente limpia (progresión ×2 aproximada) y ya está bien adoptada en el código. Se agregan dos tokens que hoy faltan:

- `hairline = 1` (grosor de borde estándar, hoy hardcodeado como `1` o `2` de forma inconsistente entre widgets).
- `micro = 2` (para separaciones dentro de badges/chips pequeños, hoy ausente, forzando el uso de `xs=4` incluso cuando es demasiado).

`cardRadius` (20) y `buttonRadius` (16) se preservan como valores base y se integran a la escala completa del Capítulo 10.

---

## Capítulo 8 — Elevation

**Autocrítica de v1.0:** la versión anterior de este capítulo hablaba de "niveles de elevación" — literalmente el vocabulario del eje-Z de Material Design, solo que con sombras de color en vez de sombras grises. Eso es cambiar el disfraz, no el modelo mental. Un crítico de Linear preguntaría de inmediato: ¿esto describe una posición física en el espacio (metáfora de Apple/Material, "qué tan cerca está de mí") o describe importancia narrativa ("qué tanto me debo detener aquí")? La v1.0 mezclaba ambas sin decidir. Bufón no necesita un eje-Z — el isotipo es completamente plano, sin ninguna superposición de capas. Lo que sí necesita es una forma de decir "esto importa más que el resto de la pantalla", y eso es una pregunta de **foco narrativo**, no de altura física.

Se reemplaza "Elevation" (concepto físico) por **Capas de Foco** (concepto narrativo), con tres capas, no niveles:

1. **Ambiente.** El 90% de los componentes. Se diferencian del fondo por color plano (Graphite vs. Graphite+1, o Paper vs. blanco) o un borde hairline — nunca por sombra. Esta capa es intencionalmente silenciosa.
2. **Protagonista.** El único elemento de foco absoluto de la pantalla (Capítulo 3, ley 4). Se separa del Ambiente con la sombra de color descrita en `BRAND PHYSICS` (nunca sombra gris) — esto ya existe parcialmente en `AnimatedPrimaryButton` (sombra al 30% del propio color) y se convierte en el estándar, no la excepción. Solo puede haber un elemento en capa Protagonista por pantalla a la vez; si hay dos, alguno debe bajar a Ambiente.
3. **Ceremonial.** Reservada exclusivamente al momento de Ganador de la Noche. Es la única capa que se permite romper las otras reglas del sistema (degradado Butter→Graphite o Butter→Mint a pantalla completa) — precisamente porque comunica "esto rompe las reglas porque se lo ganó", no porque necesite "más altura".

---

## Capítulo 9 — Shapes

*Nota de la revisión v1.1: Shapes (9), Corners (10) y Borders (11) son, en la práctica, una sola decisión de geometría — un crítico de Notion señalaría correctamente que separarlas en tres capítulos fragmenta un sistema que debería leerse de corrido. Se mantienen como tres capítulos porque el roadmap del Capítulo 35 ya los referencia por separado, pero deben leerse como una sola unidad: 9 define QUÉ formas existen, 10 define CUÁNTO se redondean, 11 define CÓMO se separan cuando no hay suficiente contraste de color para hacerlo solas.*

Vocabulario de forma cerrado, derivado directamente de la geometría del isotipo:

- **Círculo perfecto:** avatares, badges de logro, el propio timer circular (ya existe en `timer_widget.dart`), botón de acción flotante. Ecoa la cabeza del bufón y los cascabeles.
- **Pastilla (radio completo):** botones primarios, chips de filtro, tags de estado ("En línea", "Host"). Ecoa la forma de las letras del logotipo.
- **Rectángulo superredondeado (radio 20-28):** tarjetas de contenido, modales, la tarjeta de pregunta/respuesta.
- **Nunca:** esquinas rectas (radio 0-4) en ningún componente interactivo. Se permiten únicamente en elementos de fondo estructural no interactivo (por ejemplo, un separador de sección a ancho completo).

---

## Capítulo 10 — Corners

Escala de radio formalizada (evoluciona los dos valores existentes en `AppSpacing`):

| Token | Valor | Uso |
|---|---|---|
| `radius-xs` | 8 | Chips pequeños, badges inline |
| `radius-sm` | 12 | Inputs de texto, tooltips |
| `radius-md` | 16 (=`buttonRadius` actual) | Botones, inputs grandes |
| `radius-lg` | 20 (=`cardRadius` actual) | Tarjetas estándar |
| `radius-xl` | 28 | Modales, tarjetas hero (pregunta activa, ganador) |
| `radius-full` | 999 | Pastillas, avatares, círculos |

---

## Capítulo 11 — Borders

Con el degradado desterrado a "ceremonial" (Capítulo 8), el borde gana peso como herramienta de separación estructural:

- Grosor estándar: `hairline` (1dp) para separación pasiva; `2dp` reservado para estados de selección/foco activo (ya el patrón en `GameCard` cuando `isSelected`).
- Color: `paper-line`/`graphite+1` para bordes neutros; el color semántico (mint/coral/lavender) SOLO en el borde cuando ese borde comunica estado, nunca como decoración.
- Nunca bordes con degradado ni doble borde — un componente tiene como máximo un borde activo a la vez.

---

## Capítulo 12 — Iconography

La iconografía Material outline actual (`Icons.sports_esports`, `Icons.timer_outlined`, `Icons.lock_outline`) es delgada y neutra — contradice el trazo grueso y sólido del isotipo. Reglas:

- Preferir siempre la variante **rellena/bold** de cualquier ícono de Material Symbols sobre la outline (`Icons.timer` en vez de `Icons.timer_outlined`) como parche de corto plazo, mientras no exista un set propio.
- **Autocrítica de v1.0:** recomendar Phosphor Bold/Fill como dirección final era quedarse corto — Phosphor es hoy el "Feather Icons de esta generación", adoptado tan masivamente que ya no comunica nada propio; usarlo tal cual sería resolver el problema de Material genérico cambiándolo por un genérico distinto, más nuevo. La dirección correcta es un **set custom pequeño** (15-20 íconos que cubren el 90% de los usos reales: timer, sala, votar, compartir, perfil, corona/ganador, sonido, configuración) trazado para compartir EXACTAMENTE el radio de esquina y grosor de trazo del isotipo — no "inspirado en" sino literalmente construido con la misma retícula. El resto de los íconos poco frecuentes puede seguir viniendo de Material Symbols Bold como fallback aceptable; los 15-20 de alto uso no.
- Tamaño mínimo interactivo: 24dp de ícono dentro de un área táctil de 48dp mínimo.
- Ningún ícono se usa nunca en negro puro sobre Graphite ni en blanco puro sobre Butter — siempre `ink`/`paper` según el token de superficie.

---

## Capítulo 13 — Illustration style

Hoy no existe ilustración propia (los estados vacíos usan íconos Material sueltos, confirmado en `leaderboard_screen.dart`). Se define la dirección: extensión directa de la gramática facial del isotipo — formas geométricas planas, expresión reducida a 2-3 trazos (ojos cerrados felices, o una sola ceja levantada para sorpresa, boca como arco simple), paleta de máximo 2 colores de marca + Ink por ilustración, sin sombreado ni textura. Cada ilustración de estado vacío/error debe poder leerse como "un pariente visual" de la cara del bufón, nunca como un clip-art genérico de "sala vacía" o "sin conexión".

---

## Capítulo 14 — Component philosophy

- **Tokens, nunca literales.** Ningún componente nuevo declara un `Color(0xFF...)` o un número de spacing suelto — todo referencia `AppColors`/`AppSpacing`/`AppTypography` (o sus sucesores). El actual `paywall_screen.dart` con colores hardcodeados (`Color(0xFF1A1A2E)`, `Color(0xFFE94560)`, etc.) es el ejemplo de lo que ya no debe volver a pasar.
- **Estados explícitos, no implícitos.** Todo componente interactivo maneja explícitamente: default, pressed, selected, disabled, loading. Si un componente no puede definir los cinco, no está terminado.
- **Composición sobre configuración.** Preferir construir variantes componiendo un componente base con slots (`icon`, `trailing`) — patrón ya usado correctamente en `GameCard`/`AnimatedPrimaryButton` — en vez de flags booleanas que se multiplican.

---

## Capítulo 15 — Interaction philosophy

- Cada tap relevante responde en menos de 100ms visualmente, incluso si la operación real (red) tarda más — el feedback óptico nunca espera al servidor.
- Ningún tap "muere en silencio": todo control interactivo tiene al menos un estado de press visible.
- Un objetivo táctil mínimo de 48×48dp, sin excepción, incluyendo elementos que hoy son texto plano clickeable.
- Una acción primaria por pantalla, siempre en la posición de mayor peso visual (nunca compitiendo con una acción secundaria del mismo tamaño/color).

---

## BRAND PHYSICS

*Las mejores apps obedecen una física propia: en Apple, todo tiene peso; en Discord, todo flota; en Duolingo, todo rebota. Los Capítulos 16 y 17 (Motion language, Animation timing) son la implementación técnica de esta física — esta física es la ley que los justifica.*

**La física de Bufón es Compresión y Resorte — porque el juego mismo es eso.** El mecanismo central de Bufón es contener algo (una respuesta, un voto, un secreto) y luego soltarlo en el momento correcto. La física visual debe ser literalmente la misma idea aplicada a cómo se mueven los objetos: **todo en Bufón se comprime antes de actuar, y se libera con un pequeño exceso cuando actúa** — nunca un movimiento neutro y simétrico de entrada/salida.

Reglas concretas, suficientemente específicas para que un animador las siga sin ambigüedad:

**Reposo — nada está completamente quieto.** Los elementos protagonistas (Capítulo 8, capa Protagonista) tienen una "respiración" apenas perceptible: escala oscilando entre 1.0 y 1.008, período de 3-4 segundos, curva `easeInOut`. Los elementos de la capa Ambiente NUNCA respiran — el reposo absoluto se reserva para que la respiración del protagonista se note.

**Al tocar — se comprime, no se ilumina.** Cualquier objeto tocado escala hacia adentro (0.95-0.97, ya el valor real en el código) en 80-120ms con curva `easeIn` rápida — esto es "cargar el resorte". Nunca un cambio de opacidad o de color como única respuesta al toque; siempre hay compresión física.

**Al soltar sin confirmar — vuelve sin exceso.** Si el toque se cancela (el dedo se desliza fuera, o la acción no se confirma), el objeto vuelve a 1.0 a la misma velocidad de entrada, sin rebote — no ganó nada, no hay resorte que liberar.

**Al confirmar una acción — se libera con exceso.** Cuando la acción SÍ se confirma (se envía la respuesta, se emite el voto), el objeto rebasa 1.0 levemente (hasta 1.03-1.05) antes de asentarse, con una curva tipo `easeOutBack` — es el resorte soltándose. Esto es lo que distingue un "toque que no pasó nada" de un "toque que causó algo".

**Al aparecer — nunca desde la nada.** Ningún elemento nuevo hace fade-in puro. Todo entra ya "comprimido" (empieza en 0.85-0.9 de escala) y se expande hasta 1.0 con leve rebote — como un sello golpeando papel, no como una aparición fantasma.

**Al desaparecer — depende de si se descarta o se consume.** Un elemento que el usuario RECHAZA o CIERRA se encoge y se desvanece hacia su propio centro (se "guarda"). Un elemento que se CONSUME como parte del flujo (una respuesta que se envía, un voto que se registra) no desaparece en su lugar — se contrae *viajando* hacia el contador o destino que lo recibe, implicando continuidad, no borrado.

**Aceleración — nunca simétrica.** Ninguna animación usa una curva `linear` ni una `easeInOut` perfectamente simétrica como default. La compresión es rápida (entra rápido a la tensión); la liberación es más lenta y con overshoot (sale despacio del resorte). Esta asimetría es la firma física central del sistema.

**Celebración — el resorte más grande, reservado.** Solo en Ganador de Ronda/Noche se permite una compresión-liberación de amplitud mayor (hasta 1.1-1.15 de overshoot) — es el único momento donde "el resorte más fuerte que existe en el sistema" se dispara, y por eso debe seguir sintiéndose especial (ver Capítulo 32, la escalera de intensidad corta).

**Espera — coiled, no muerto.** Durante "esperando a los demás" (lobby, esperando votos), los elementos relevantes pulsan a amplitud MUY baja y velocidad LENTA — la sensación física correcta es "algo enrollado, listo, pero paciente", no "pantalla congelada" ni "actividad frenética sin propósito".

**El gesto ownable: el reveal como mirilla.** El detalle del "ojo de cerradura" del gorro del isotipo (Capítulo 2) se convierte en una física real: la transición de Reveal no es un cross-fade — es una máscara circular que se expande desde el centro, como si se abriera literalmente una mirilla sobre el contenido oculto. Es el único momento donde la física dejar de ser "resorte" y se vuelve "apertura" — coherente porque es, literalmente, la revelación de un secreto guardado.

**El tacto nunca se ignora.** Todo objeto interactivo reacciona dentro de un frame al toque — la masa percibida es baja (reacciona rápido) pero no nula (no es plano ni instantáneo sin transición); esto es lo que impide que la app se sienta "muerta" o, en el extremo opuesto, "sin peso" como un slider de sistema operativo genérico.

---

## RHYTHM SYSTEM

*No es sobre animaciones individuales (eso es Capítulo 16/17) — es sobre el pulso del producto completo, medible incluso con el sonido apagado.*

Bufón tiene un ritmo de **diente de sierra ascendente**: cada ronda es un ciclo completo de tensión y liberación (un "diente"), pero el punto de partida de cada diente es más alto que el anterior, hasta el pico final en el Ganador de la Noche. Ver la fila 10 de `EMOTIONAL JOURNEY` para el detalle emocional; esto es su traducción a reglas de producto.

**Presupuesto de silencio por ronda.** De la duración total de una ronda (Responder + Votar + Reveal + Resultado, típicamente 90-150s), aproximadamente **65-70% debe sentirse "contenido"** (responder bajo presión, votar en silencio, el silencio de transición) y solo **30-35% debe sentirse "liberado"** (el reveal, la celebración). Invertir esta proporción —hacer que la mayoría del tiempo sea celebración— agota el impacto del estallido; es la razón por la que el reveal actual (dos etapas de 750-800ms cada una, sobre una ronda de 90-150s) ya respeta la proporción correcta, y es una restricción que cualquier cambio futuro al timing debe seguir respetando.

**La regla del piso ascendente.** El nivel de "reposo" entre rondas (Capítulo 32, etapa "Respiro") nunca vuelve exactamente al mismo punto de calma que la ronda anterior — el ritmo visual (velocidad de las transiciones, densidad de elementos en pantalla, cadencia del copy) debe acelerarse sutilmente ronda tras ronda. Esto se logra sin tocar la lógica de juego: por ejemplo, la pausa antes de iniciar la siguiente ronda puede acortarse ligeramente (de 5s en la ronda 1 a 3s en la última ronda), y el copy de transición puede volverse progresivamente más directo/urgente (`game_copy.dart` ya tiene la voz para esto, falta la progresión).

**Sin sonido, el ritmo se lee en densidad de movimiento, no en volumen.** Un jugador con el teléfono en silencio (el caso más común en una mesa social) debe poder sentir "ahora viene algo" solo por CUÁNTOS elementos empiezan a moverse a la vez y a qué velocidad — el silencio visual real (nada animándose) antes del reveal es, en sí mismo, la señal, exactamente como el `EMOTIONAL JOURNEY` prescribe cero movimiento en la etapa 6.

**Cuándo el ritmo se detiene por completo (y por qué eso es correcto).** Los únicos dos momentos de "cero ritmo" deliberado son: (1) el silencio de 2-3s antes del reveal, y (2) el Lobby mientras se espera a que se una gente — este segundo es distinto: no es tensión contenida, es una pausa social genuina, y el sistema NO debe llenarlo de movimiento artificial para "no aburrir" (ver Capítulo 24, la ilustración "respirando" es suficiente) — confundir estos dos silencios (uno cargado, uno relajado) y tratarlos igual sería aplanar el ritmo que este capítulo existe para proteger.

**Métrica de salud del ritmo:** si se graba una sesión completa y se reproduce en x4 sin sonido, un observador externo debería poder señalar aproximadamente en qué segundos ocurrieron los reveals solo por los picos de movimiento — si no puede, el producto se aplanó y perdió su ritmo reconocible.

---

## Capítulo 16 — Motion language

Vocabulario de movimiento con nombre, para que cualquier desarrollador futuro elija de una lista en vez de inventar valores nuevos cada vez:

| Nombre | Qué hace | Curva | Ya existe en |
|---|---|---|---|
| **Press** | Escala 1.0→0.95-0.97 al presionar | `easeInOut`, 100-150ms | `animated_primary_button.dart`, `game_card.dart` |
| **Pulse** | Escala 1.0→1.03-1.1 y vuelve, para llamar la atención sin interacción del usuario | `easeInOut`, 500ms | `timer_widget.dart`, `game_card.dart` (al seleccionar) |
| **Arrive** | Entrada de un elemento nuevo en pantalla: fade + slide sutil desde abajo | `easeInOut`, 250ms | `page_transitions.dart` (`FadeSlidePageRoute`) |
| **Reveal** | Secuencia de 2-3 etapas con pausa dramática entre cada una | delays de 750-800ms entre etapas | `round_result_screen.dart` (`_revealStage`) |
| **Swap** | Un texto/valor reemplaza a otro sin salto brusco | `AnimatedSwitcher`, 250ms | `timer_widget.dart` (copy de urgencia) |
| **Settle** | Contenedor que cambia de tamaño/color suavemente tras una acción | `easeInOut`, 200-300ms | `animated_primary_button.dart`, `game_card.dart` |

Regla: cualquier animación nueva debe mapear a uno de estos seis nombres o justificar por qué necesita un séptimo.

---

## Capítulo 17 — Animation timing

Escala oficial de duración (formaliza los valores que YA aparecen dispersos en el código):

| Tier | Duración | Uso |
|---|---|---|
| Micro | 100-150ms | Press, feedback táctil inmediato |
| Estándar | 200-300ms | Arrive, Swap, Settle — la mayoría de las transiciones de UI |
| Dramática | 600-900ms | Cada etapa individual de un Reveal |
| Celebratoria | 1200-2000ms+ | Secuencia completa de Ganador de la Noche, con múltiples etapas superpuestas |

Ninguna animación nueva usa un número fuera de estos cuatro rangos sin justificación explícita documentada en el PR.

---

## Capítulo 18 — Microinteractions

Catálogo mínimo obligatorio — si una pantalla tiene el elemento de la izquierda, debe tener el comportamiento de la derecha:

- Botón primario → Press + haptic light + sonido tap (ya existe, extender a Home/Lobby).
- Tarjeta seleccionable (respuesta a votar) → Press + Pulse al confirmar selección + haptic medium (ya existe en `GameCard`).
- Código de sala → tap para copiar dispara un `Swap` de ícono (copiar → check) + haptic selection, nunca solo un Snackbar silencioso.
- Timer bajo 10s → Pulse continuo + haptic light en cada segundo bajo 5s (ya existe).
- Contador de "N de M respondieron" → cada incremento anima el número con un `Settle`, nunca un salto instantáneo de texto.

---

## Capítulo 19 — Haptics

El vocabulario de `HapticService` ya es correcto y completo — el problema es de **cobertura**, no de diseño. Se formaliza el mapeo oficial por momento:

| Momento | Haptic | Estado actual |
|---|---|---|
| Tap de botón/navegación | `lightImpact` | Falta en Home/Lobby |
| Selección de respuesta a votar | `mediumImpact` | Ya implementado |
| Envío de respuesta/voto confirmado | `mediumImpact` | Ya implementado |
| Timer bajo 5s, cada segundo | `lightImpact` | Ya implementado |
| Reveal, etapa 1 | `lightImpact` | Ya implementado |
| Reveal, etapa 2 / Ganador de ronda | `celebration()` (heavy→medium→light) | Ya implementado |
| Ganador de la noche | `celebration()` + repetición al aparecer cada elemento de la tarjeta de stats | Falta la repetición |
| Error / bloqueo (paywall, límite) | `heavyImpact` (vía `error()`) | Falta — hoy los errores no tienen haptic |
| Crear/unirse a sala exitoso | `mediumImpact` | Falta — Home no dispara nada hoy |

**Economía de haptics (agregado en v1.1).** El Capítulo 22 ya establece que el confetti es un recurso escaso para que la celebración grande siga sintiéndose grande — un crítico de Supercell señalaría que la v1.0 no aplicó la misma disciplina al haptic: prescribir `lightImpact` en CADA tap (incluyendo cada segundo del timer bajo 5s, cada tap de navegación) durante una sesión de 20-30 minutos puede volverse ruido táctil que el jugador deja de notar, exactamente lo que le pasaría al confetti si apareciera en cada voto. Regla nueva: dentro de una misma pantalla, dos haptics del mismo tipo (`lightImpact`) separados por menos de 400ms se colapsan en uno solo — el timer bajo 5s, por ejemplo, no dispara 5 `lightImpact` idénticos, sino una intensidad que aumenta ligeramente (`lightImpact` → `lightImpact` → `mediumImpact` en el último segundo), para que el cuerpo perciba una escalada, no una repetición.

---

## Capítulo 20 — Audio language

**Estado honesto:** hoy no existe una biblioteca de sonido propia — `SoundService` reproduce únicamente los dos sonidos de sistema de iOS/Android (`click`, `alert`). **Autocrítica de v1.0:** la primera versión de este capítulo resolvió la dirección sonora en dos palabras ("madera", "campanas") — eso no es una identidad sonora, es una etiqueta. Un crítico de Teenage Engineering lo diría sin rodeos: si no puedes describir de qué estaría hecha tu interfaz si pudiera tocarse, todavía no sabes cómo debe sonar tampoco. Esta versión responde esa pregunta primero.

### ¿De qué material está hecha la interfaz de Bufón?

Si Bufón fuera un objeto físico sobre la mesa, sería una combinación deliberada de cuatro materiales, cada uno con un rol — y es igual de importante decir qué materiales están **excluidos**:

- **Cartulina/papel grueso (cardstock).** El material base de todo lo que "existe en pantalla" — cartas, tarjetas de pregunta, la superficie sobre la que ocurre el juego. Sonido: seco, corto, satisfactorio, sin resonancia metálica — el sonido de una carta bien impresa cayendo sobre una mesa de madera.
- **Madera.** Los tokens/fichas de interacción rápida — taps, selecciones, navegación. Sonido: un "clac" corto y cálido, como fichas de un juego de mesa moviéndose.
- **Un sello de goma con tinta (rubber stamp).** Reservado exclusivamente a las acciones de **confirmación con peso** — enviar una respuesta, emitir un voto. Sonido: un golpe seco y satisfactorio de sello contra almohadilla, con un pequeño "thunk" grave — coherente con que votar es literalmente "estampar un veredicto" sobre un amigo.
- **Una campana pequeña de metal (bell).** El único acento metálico permitido en todo el sistema, reservado EXCLUSIVAMENTE al reveal y a la celebración — es el eco directo de los cascabeles del gorro del isotipo. Precisamente porque es el único metal del sistema, debe sonar especial cada vez.

**Materiales excluidos deliberadamente:** vidrio/cristal (demasiado frío, demasiado "tech premium" genérico — es el sonido de Apple/fintech, no el de Bufón), sintetizadores digitales tipo "chime" de notificación (es el sonido de cualquier app corporativa), percusión electrónica de videojuego arcade (rompe el registro "mesa de juego entre amigos" y lo empuja a "videojuego"), y textiles (no aportan nada al registro — se excluyen por simple ausencia de relación con el objeto).

### Mapa de sonidos por momento (a construir)

| Momento | Material | Descripción sonora |
|---|---|---|
| Tap de botón/navegación | Madera | Clac corto, seco, cálido |
| Envío de respuesta | Cartulina + sello | Deslizamiento breve de papel + golpe de sello suave |
| Voto emitido | Sello | Golpe de sello franco, ligeramente más grave que el de responder — un veredicto pesa más que una ocurrencia |
| Reveal, etapa 1 | Cartulina | Un "flip" de carta girándose — anticipación, no resolución |
| Reveal, etapa 2 / Ganador de ronda | Campana | Un solo repique breve y brillante — la única campana que suena en toda una ronda |
| Ganador de la noche | Campana (extendida) | Secuencia de 2-3 repiques ascendentes, la única vez que la campana suena más de una vez seguida en todo el sistema |
| Error/bloqueo | Madera (grave) | Un "toc" grave y corto — nunca un buzzer, nunca un tono descendente dramático; es un obstáculo menor, no un fracaso |

**Regla de escasez sonora (coherente con el Capítulo 22):** la campana es el sonido más raro del sistema — si se usara también para éxitos menores (responder, votar), dejaría de significar "algo importante acaba de pasar". Cartulina y madera cubren el 90% de las interacciones; el sello cubre confirmaciones; la campana cubre exactamente dos momentos por ronda.

**El sonido de marca (a desarrollar en Fase 3C o posterior):** el repique de campana del Reveal etapa 2 es candidato directo a convertirse en el "sonido de marca" ownable de Bufón — el equivalente al "ta-dum" de Netflix o el timbre de Intel. Debe componerse una sola vez, con cuidado, y no volver a cambiar una vez fijado, precisamente porque su valor está en la repetición reconocible a través de miles de partidas.

---

## Capítulo 21 — Particles

`ConfettiWidget` ya tiene una mecánica sólida (50 partículas, gravedad, rotación, `CustomPainter` performante). Se preserva íntegro el motor; se recablea únicamente la paleta:

```
// Antes (app_colors.dart actual):
[Gold #FFD700, Red #E94560, Cyan #00D9FF, Coral #FF6B6B, Turquoise #4ECDC4, Salmon #FFA07A]

// Después:
[Butter, Mint, Sky, Lavender, Coral] — mezcla ponderada 40% Butter, 15% cada uno del resto
```

---

## Capítulo 22 — Confetti system

Regla de aparición — el confetti es un recurso escaso, no decorativo:

- **Sí:** Ganador de ronda (etapa 2 del reveal), Ganador de la noche.
- **No:** envío de respuesta, voto emitido, unirse a sala, ni ningún logro menor de progresión — estos usan `Pulse` + haptic, no partículas.
- Densidad: 50 partículas para ganador de ronda (ya el valor actual), 80-100 para ganador de la noche (el único momento que se permite escalar la intensidad).
- Duración: 3s para ronda (actual), hasta 4-5s para la noche, con fade-out gradual, no corte abrupto.

---

## Capítulo 23 — Transition choreography

El loop de juego es un circuito de una sola dirección: Lobby → Responder → Votar → Reveal → Resultado → (siguiente ronda o Ganador). Todas las transiciones de avance usan `Arrive` (fade+slide desde abajo, ya construido en `FadeSlidePageRoute`) para reforzar la sensación de "avanzar". Las transiciones de salida/retroceso (salir de una sala, volver a Home) usan un fade simple sin slide, para que se sientan claramente distintas de "avanzar en el juego". Hoy `FadeSlidePageRoute` solo se usa en `presentation/screens/` — este documento exige extenderlo a las 6 pantallas del loop principal (`lib/screens/`), que hoy navegan con `MaterialPageRoute` seco.

---

## Capítulo 24 — Loading philosophy

Nunca un `CircularProgressIndicator` desnudo sobre fondo vacío (patrón actual en `paywall_screen.dart` y dentro de `AnimatedPrimaryButton.isLoading`). Se reemplaza por: (1) dentro de botones, el spinner se mantiene pero en el color de marca correspondiente, nunca blanco genérico; (2) para cargas de pantalla completa (uniéndose a sala, cargando perfil), un estado de espera con forma reconocible — por ejemplo el óvalo de la cara del bufón "respirando" (escala sutil en loop) en vez de un spinner circular genérico de Material.

---

## Capítulo 25 — Empty states

Cada estado vacío (leaderboard sin datos, sin logros, sin historial de temporada) necesita: una ilustración de la familia del Capítulo 13 (nunca un ícono Material suelto como hoy en `leaderboard_screen.dart`), un titular con voz de marca (nunca "No hay datos"), y máximo una acción. Ejemplo de tono: en vez de "No hay resultados todavía", algo como "Todavía nadie se ha ganado el trono. Sé el primer bufón de la tabla."

---

## Capítulo 26 — Error states

Coral es el único color permitido para comunicar error. Nunca se muestra un mensaje de excepción crudo — hallazgo concreto a corregir: `paywall_screen.dart` hoy hace `_showError('Error al procesar la compra: $e')`, exponiendo el error técnico crudo al jugador. Todo error visible al usuario pasa por copy con voz de marca ("Algo se atoró. Inténtalo de nuevo en un momento.") con el detalle técnico solo en logs/analytics, nunca en pantalla. El tono de error nunca culpa al jugador.

---

## Capítulo 27 — Success states

Mint es el único color de éxito. Los éxitos pequeños (respuesta enviada, voto registrado) usan confirmación inline silenciosa (cambio de color/ícono del propio elemento) — nunca un modal ni un Snackbar de pantalla completa. Los éxitos grandes (ganar la ronda, ganar la noche) sí ocupan la pantalla completa, siguiendo el Capítulo 22.

---

## Capítulo 28 — Accessibility

- Contraste mínimo AA (4.5:1) verificado en los pares reales del sistema: Ink `#191919` sobre Butter `#F8EE67` (contraste alto, aprobado), Ink sobre Paper `#FAFAF7` (aprobado), Paper `#FAFAF7` sobre Graphite `#242320` (aprobado) — los tres pares de texto principales cumplen sin necesitar ajuste.
- Ningún estado se comunica solo por color: el timer en peligro cambia de color Y pulsa Y vibra; un error es Coral Y tiene un ícono Y un mensaje de texto.
- Todos los componentes interactivos ≥48×48dp (Capítulo 15).
- Soporte de `MediaQuery.textScaler` — ningún texto usa tamaños fijos que rompan con Ajustes de Accesibilidad de iOS/Android al 150-200%.
- Respetar `MediaQuery.disableAnimations`/reduce motion: todo `Pulse`/`Reveal` debe tener una versión reducida (cross-fade simple) cuando el sistema lo pide.

---

## Capítulo 29 — Dark mode

Graphite es la base del modo oscuro — pero ya no es el modo "por defecto y único" como hoy. El modo oscuro es el registro de **"el juego en vivo"**: Responder, Votar, Reveal, Resultado, Ganador — los momentos donde todos miran la misma pantalla como si fuera un escenario iluminado en una habitación oscura. Usa Graphite/Graphite+1 como fondos, Butter/Mint/Lavender/Coral como acentos puntuales, Paper como texto.

---

## Capítulo 30 — Light mode

Paper es la base del modo claro — que **hoy no existe en el código** y es la brecha más grande de todo este sistema. Es el registro de **"la vida social alrededor del juego"**: Home, Lobby, Perfil, Leaderboard, Temporadas — momentos de lectura y decisión, no de espectáculo. Usa Paper/blanco como fondo, Ink como texto, Butter como color de botones/acento primario (tal como aparece en la dirección visual original: "pantallas claras: Paper + botones Butter").

---

## Capítulo 31 — Sistema de screenshots compartibles

Ya existen `share_victory_card.dart` y `share_profile_card.dart` — se preservan como los puntos de extensión correctos. **Autocrítica de v1.0:** la versión anterior daba una sola plantilla genérica (fondo Butter, número gigante, isotipo en la esquina) para cualquier tipo de tarjeta — eso es una plantilla, no un sistema; distintos contenidos necesitan distintas composiciones para seguir sintiéndose como el "elemento gigante, todo lo demás diminuto" del Capítulo 3 en vez de simplemente reciclar el mismo layout con texto distinto.

Reglas comunes a toda tarjeta compartible: fondo Butter a página completa (nunca Graphite — debe verse alegre incluso fuera de contexto), el isotipo pequeño en una esquina fija (nunca centrado, nunca compitiendo con el contenido), espacio negativo generoso.

Reglas específicas por tipo:

- **Tarjeta de Ganador de la Noche:** el protagonista absoluto es el AVATAR del ganador (no un número) — el logro es "quién fue", no "cuánto sacó". El puntaje aparece diminuto, casi una nota al pie.
- **Tarjeta de "peor/mejor respuesta de la noche"** (oportunidad nueva, ver roadmap): el protagonista es el TEXTO de la respuesta en sí, en comillas grandes, con el nombre del autor diminuto debajo — esto es más compartible que cualquier stat, porque el chiste es el contenido.
- **Tarjeta de perfil/racha:** el protagonista es el NÚMERO (racha, victorias totales) — aquí sí aplica la plantilla original de v1.0, porque el logro real es cuantitativo.
- **Tarjeta de leaderboard/temporada:** el protagonista es la POSICIÓN (#1, #2) con el nombre como segundo elemento — nunca una tabla completa comprimida, que rompería la ley de "un elemento gigante" del Capítulo 3.

La pregunta que decide la composición de cualquier tarjeta nueva: *¿qué es lo que la persona quiere que sus amigos vean primero?* Esa respuesta es siempre el elemento gigante; todo lo demás es soporte.

---

## Capítulo 32 — Sistema de celebraciones

Tres tiers, cada uno con su combo fijo de partículas + haptic + sonido + duración:

| Tier | Momento | Partículas | Haptic | Duración |
|---|---|---|---|---|
| Pequeño | Voto/respuesta registrados | Ninguna | `mediumImpact` | Instantáneo |
| Medio | Ganador de ronda | 50 (Capítulo 22) | `celebration()` | 3s |
| Grande | Ganador de la noche | 80-100 | `celebration()` repetida en cada stat revelada | 4-5s con etapas |

Ningún momento nuevo introduce un cuarto tier sin pasar antes por revisión de diseño — la escalera de intensidad es intencionalmente corta para que "Grande" siga sintiéndose grande.

---

## Capítulo 33 — Cómo debe sentirse cada fase del juego

| Fase | Registro de color | Ritmo | Sensación objetivo |
|---|---|---|---|
| **Lobby** | Butter, modo claro | Lento, expectante | "Estamos a punto de empezar algo" |
| **Respuesta** | Graphite + Sky | Íntimo, con presión creciente (timer) | "Solo yo y mi ingenio contra el reloj" |
| **Votación** | Graphite + Lavender | Suspenso silencioso | "Estoy juzgando en secreto" |
| **Reveal** | Graphite + Butter, en dos etapas | Contenido → explosivo | "El telón se abre" |
| **Ganador (ronda)** | Graphite + Mint + confetti | Explosivo, breve | "Victoria momentánea, ya viene la siguiente" |
| **Ganador (noche)** | Butter/Graphite ceremonial + confetti extendido | Explosivo, sostenido | "Esto va a ser una captura de pantalla" |
| **Perfil** | Paper, modo claro | Calmo | "Este soy yo, mi historial" |
| **Leaderboard** | Paper con acentos Sky/Lavender | Neutro-competitivo | "¿Dónde estoy parado?" |
| **Paywall** | Paper o Graphite (no casino oscuro actual) | Directo, sin fricción visual | "Aquí está la opción, sin presión artificial" |
| **Temporadas** | Butter + Lavender | Ceremonial-narrativo | "Algo más grande está pasando con el tiempo" |

---

## Capítulo 34 — Qué JAMÁS debería hacer Bufón visualmente

- Nunca usar degradado como tratamiento por defecto de un botón o tarjeta (Capítulo 8 lo reserva a lo ceremonial).
- Nunca usar iconografía outline delgada de Material sin modificar.
- Nunca mostrar un mensaje de error con texto de excepción técnica cruda.
- Nunca usar más de un color de acento como protagonista en la misma pantalla.
- Nunca usar esquinas rectas en un componente interactivo.
- Nunca animar con un simple fade lineal de Material sin escala/rebote — toda entrada usa el vocabulario del Capítulo 16.
- Nunca usar confetti para un logro menor (diluye el impacto de los momentos grandes).
- Nunca usar un tono de urgencia falsa/manipulador en monetización (temporizadores de countdown artificiales, "¡Solo queda 1!" sin que sea cierto).
- Nunca dejar que el copy de error o derrota suene punitivo hacia el jugador.
- Nunca usar gris medio neutro como fondo de contenido importante.
- Nunca disparar el mismo haptic repetido más de dos veces seguidas sin escalar su intensidad (Capítulo 19) — el cuerpo deja de notarlo, igual que el ojo deja de notar un color repetido sin variación.
- Nunca hacer sonar la campana (Capítulo 20) fuera del reveal y la celebración — es el único sonido metálico del sistema y su rareza es lo que lo hace significar algo.
- Nunca adoptar una fuente o un set de íconos solo porque "así se ve amigable" — si la elección tipográfica o de iconografía es la misma que usarían diez apps de fiesta genéricas, no sirvió para diferenciar a Bufón (Capítulos 6 y 12).
- Nunca resolver una pregunta de jerarquía de importancia (qué elemento manda en la pantalla) con el vocabulario de "elevación física" de Material/Apple — Bufón usa Capas de Foco (Capítulo 8), no altura.

---

## FIRMA VISUAL DE BUFÓN

*Entre 5 y 10 elementos que deben sobrevivir aunque cambien la UI, las pantallas, las funciones, el equipo, Flutter o Material Design. Si dentro de cinco años Bufón se ve completamente distinto pero conserva estos elementos, sigue siendo Bufón. Si los pierde todos, aunque el logo siga en la esquina, dejó de serlo.*

1. **El par Butter + Ink al máximo contraste**, sin matices intermedios, como firma cromática de los momentos de umbral (antes/después de jugar).
2. **La sustitución de una forma circular por una cara** — el dispositivo central del logotipo (la "O" que es un rostro) debe seguir siendo la lógica detrás de cómo Bufón trata avatares, badges y cualquier elemento circular con expresión.
3. **Los ojos cerrados en arco feliz** como la única gramática de expresión de cualquier personaje/ilustración — nunca ojos abiertos, nunca cejas, siempre complicidad en vez de sorpresa.
4. **El detalle del "ojo de cerradura" en vez de campana tradicional** — el motivo visual y narrativo de "esto guarda un secreto hasta que decide revelarlo", que ahora también es una física real (la mirilla del reveal, `BRAND PHYSICS`).
5. **Cero esquinas rectas en cualquier elemento interactivo**, sin excepción, para siempre.
6. **La física de Compresión y Resorte** (`BRAND PHYSICS`) como ley de movimiento — todo se comprime antes de actuar y se libera con exceso al confirmar.
7. **El silencio deliberado antes de cada revelación** (`RHYTHM SYSTEM`) — ninguna optimización de "engagement" debe eliminar nunca esta pausa a cambio de más velocidad.
8. **La voz cómplice que nunca es cruel** — el bufón se ríe CON el jugador, nunca de él, en cualquier copy que exista, para siempre.
9. **Una pantalla, una protagonista** — la ley de jerarquía extrema del Capítulo 3, el antídoto permanente contra convertirse en un dashboard.
10. **El sello y la campana como firma sonora** — confirmar pesa como un sello, revelar suena como la única campana del sistema.

---

## Capítulo 35 — Roadmap completo de implementación visual

### Fase 3A — Design Tokens
**Objetivo:** reemplazar `app_colors.dart`/`app_typography.dart`/`app_spacing.dart` con los tokens de este documento, sin tocar ninguna pantalla todavía.
**Tareas:** reescribir `AppColors` con la paleta + rampas del Capítulo 5; agregar la fuente de marca a `pubspec.yaml`; agregar tokens `hairline`/`micro`/escala de radios del Capítulo 10 a `AppSpacing`.
**Criterios de aceptación:** `flutter analyze` limpio; la app compila y renderiza (aunque visualmente "rota" contra el theme viejo, ya que las pantallas aún no se migran); ningún archivo de pantalla se modifica en esta fase.

### Fase 3B — Component Library
**Objetivo:** actualizar los componentes reutilizables (`AnimatedPrimaryButton`, `GameCard`, `TimerWidget`, `RoundIndicator`, `GameProgressBar`) para consumir los tokens nuevos, preservando su mecánica de animación intacta.
**Criterios de aceptación:** cada componente pasa un widget test visual (golden) contra el nuevo token set; cero cambios de comportamiento/lógica, solo de apariencia.

### Fase 3C — Motion System
**Objetivo:** formalizar los 6 nombres de motion del Capítulo 16 como utilidades reutilizables (mixins/extensions) que implementen las leyes de `BRAND PHYSICS` (compresión antes de actuar, liberación con exceso al confirmar), extender `FadeSlidePageRoute` a las pantallas del loop principal, y construir el prototipo de la transición de "mirilla" (máscara circular expansiva) para el Reveal.
**Criterios de aceptación:** las 6 pantallas de `lib/screens/` navegan con la misma transición `Arrive`; ninguna transición nueva introduce un timing fuera de la escala del Capítulo 17; el Reveal usa la máscara circular en vez de un cross-fade plano; una grabación de una sesión completa a x4 sin sonido permite ubicar los reveals solo por picos de movimiento (métrica de `RHYTHM SYSTEM`).

### Fase 3D — Home + Lobby
**Objetivo:** cerrar la brecha más grande encontrada en la auditoría — migrar `home_screen.dart`/`lobby_screen.dart` del Material default a los tokens nuevos, y agregar haptics/sonido (hoy en cero).
**Criterios de aceptación:** cero usos de `Colors.*` hardcodeado en ambos archivos; cada botón dispara `Press` + haptic; Home vive en modo claro (Paper), primer uso real del Capítulo 30.

### Fase 3E — Gameplay (Responder + Votar)
**Objetivo:** recablear `game_screen.dart`/`voting_screen.dart` a Graphite/Sky/Lavender según el Capítulo 33, preservando toda la lógica de timer/transacciones intacta.
**Criterios de aceptación:** el registro de color de Respuesta y Votación es visualmente distinguible entre sí sin leer texto.

### Fase 3F — Reveal
**Objetivo:** recablear `round_result_screen.dart` a la paleta nueva, separar visualmente el scoreboard del spotlight del ganador de ronda (hallazgo de la auditoría de jugabilidad — hoy compiten por atención).
**Criterios de aceptación:** el scoreboard no es visible hasta que termina la etapa 2 del reveal.

### Fase 3G — Winner
**Objetivo:** recablear `final_winner_screen.dart` como el momento ceremonial (Capítulo 8, nivel 2), conectar el avatar real del ganador (hoy hardcodeado a `'default'`), extender el botón de compartir a todo el grupo.
**Criterios de aceptación:** el ganador se corona con su avatar equipado real; existe un CTA de compartir visible para cualquier jugador, no solo el ganador.

### Fase 3H — Perfiles
**Objetivo:** migrar `profile_screen.dart`/`profile_public_screen.dart` a modo claro (Paper), aplicar el sistema de ilustración del Capítulo 13 a estados vacíos.
**Criterios de aceptación:** cero íconos Material sueltos en estados vacíos; consistente con Home/Lobby en registro de color.

### Fase 3I — Leaderboards
**Objetivo:** migrar `leaderboard_screen.dart`/`season_details_screen.dart`, aplicar Sky/Lavender como acentos sobre Paper.
**Criterios de aceptación:** estado vacío usa ilustración de marca, no ícono Material genérico (hallazgo concreto de la auditoría, línea `_buildEmptyState`).

### Fase 3J — Pulido final
**Objetivo:** barrido completo de accesibilidad (Capítulo 28), auditoría de que ningún archivo tenga un `Color(0xFF...)` hardcodeado fuera de los tokens, revisión de copy de error contra el Capítulo 26 (empezando por `paywall_screen.dart`, que hoy expone errores técnicos crudos).
**Criterios de aceptación:** grep de `Color(0xFF` en `lib/` retorna cero resultados fuera de `app_colors.dart`; todos los pares de contraste del Capítulo 28 verificados; `flutter analyze`/`flutter test` limpios.

---

*Fin del documento. Toda decisión visual futura en Bufón debería poder justificarse citando un capítulo de este documento — y, en última instancia, trazarse de vuelta a `THE BUFÓN FEELING`. Si una regla no puede defenderse como al servicio de esos tres segundos de complicidad expuesta entre amigos, es decoración, no sistema, y debe revisarse.*
