import 'language_controller.dart';

/// Traduções dos textos fixos dos modelos (rótulos de enums e listas
/// `const`), que não podem chamar [tr] na hora de serem declarados. Os
/// modelos guardam o texto em português e o traduzem por aqui na hora de
/// mostrar, com [trKey].
const Map<String, String> modelTranslations = {
  // SvgFilterType
  'Nenhum': 'None',
  'Preto e branco': 'Black and white',
  'Inverter': 'Invert',
  // EraserTool / EraserQuality
  'Pincel': 'Brush',
  'Apagar seleção': 'Erase selection',
  'Laço': 'Lasso',
  'Retângulo': 'Rectangle',
  'Rápida': 'Fast',
  'Normal': 'Normal',
  'Alta': 'High',
  // CollageLayoutKind
  'Linha': 'Row',
  'Coluna': 'Column',
  'Grade 2x2': 'Grid 2x2',
  'Grade 2x3': 'Grid 2x3',
  'Grade 3x3': 'Grid 3x3',
  'Grade livre': 'Free grid',
  'Personalizada': 'Custom',
  // CollageExportFormat / Size / DurationRule
  'Imagem parada': 'Still image',
  'Animado, compatível com tudo': 'Animated, works everywhere',
  'Animado, arquivo menor': 'Animated, smaller file',
  'Pequeno': 'Small',
  'Médio': 'Medium',
  'Padrão': 'Default',
  'Grande': 'Large',
  'Extra grande': 'Extra large',
  'A mais longa': 'The longest',
  'Quem acabar antes segura o último quadro':
      'Shorter ones hold their last frame',
  'A mais curta': 'The shortest',
  'A montagem termina com a animação mais curta':
      'The collage ends with the shortest animation',
  // CollageColorAdjustment
  'Brilho': 'Brightness',
  'Exposição': 'Exposure',
  'Contraste': 'Contrast',
  'Realces': 'Highlights',
  'Sombras': 'Shadows',
  'Saturação': 'Saturation',
  'Matiz': 'Hue',
  'Temperatura': 'Temperature',
  // SizeVerdict
  'Leve': 'Light',
  'Envia em qualquer lugar sem problema': 'Sends anywhere without trouble',
  'Bom': 'Good',
  'Tamanho confortável para redes sociais e WhatsApp':
      'Comfortable size for social media and messaging apps',
  'Pesado': 'Heavy',
  'Pode demorar para carregar e alguns apps vão recomprimir':
      'May load slowly and some apps will recompress it',
  'Muito pesado': 'Too heavy',
  'Vários apps vão recusar ou destruir a qualidade':
      'Many apps will reject it or ruin the quality',
  // FrameStyle / ContentFitMode / ImageFrameResolutionMode
  'Sem borda': 'No border',
  'Borda fina': 'Thin border',
  'Borda média': 'Medium border',
  'Borda grossa': 'Thick border',
  'Ajuste automático': 'Auto fit',
  'Melhor enquadramento para o vídeo': 'Best framing for the video',
  'Preencher': 'Fill',
  'Preenche toda a moldura (pode cortar)': 'Fills the whole frame (may crop)',
  'Encaixar': 'Fit',
  'Mostra o vídeo inteiro com barras': 'Shows the whole video with bars',
  'Expandir sem cortar': 'Expand without cropping',
  'Preenche com fundo estendido': 'Fills with an extended background',
  'Igual à escolhida em Ajustar': 'Same as chosen in Fit',
  'Resolução do vídeo define o tamanho da moldura':
      'The video resolution sets the frame size',
  'Resolução máxima da imagem': 'Maximum image resolution',
  'Usa a resolução original da arte, no maior tamanho possível':
      "Uses the artwork's original resolution, as large as possible",
  // DitherMode / PaletteMode / OutputFormat / QuickConvertFormat
  'Sem pontilhado': 'No dithering',
  'Equilibrado': 'Balanced',
  'Máxima': 'Maximum',
  'Paleta única': 'Single palette',
  'Focada no movimento': 'Motion-focused',
  'Paleta por quadro': 'Palette per frame',
  'WebP animado': 'Animated WebP',
  // Paletas da interface
  'Morceguinho': 'Little Bat',
  'Lavanda': 'Lavender',
  'Dália': 'Dahlia',
  'Menta': 'Mint',
  'Pêssego': 'Peach',
  'Rosa': 'Pink',
  'Tríade': 'Triad',
  'Quadrada': 'Square',
  'Aurora Coral': 'Coral Aurora',
  'Turquesa Clássica': 'Classic Turquoise',
  'Turquesa Vintage': 'Vintage Turquoise',
  'Pôr do Sol Rosa': 'Pink Sunset',
  'Brisa Oceânica': 'Ocean Breeze',
  'Lilás e Creme': 'Lilac and Cream',
  'Pitaya e Limão': 'Dragon Fruit and Lime',
  'Blush e Sálvia': 'Blush and Sage',
  'Cítrico Grafite': 'Graphite Citrus',
  'Prado Nebuloso': 'Misty Meadow',
  'Orquídea Neon': 'Neon Orchid',
  'Ouro Costeiro': 'Coastal Gold',
  'Doce Meia-Noite': 'Midnight Candy',
  'Brasa e Areia': 'Ember and Sand',
  'Frutas Vermelhas': 'Berries and Cream',
  'Terracota e Lagoa': 'Terracotta Lagoon',
  'Fúcsia e Menta': 'Fuchsia and Mint',
  'Pop Tropical': 'Tropical Pop',
  'Céu e Limão': 'Sky and Lemon',
  'Noturno e Sálvia': 'Nocturne and Sage',
  'Cyber Pastel': 'Cyber Pastel',
  'Cítrico Elétrico': 'Electric Citrus',
  'Riviera Rosa': 'Pink Riviera',
  'Lagoa do Deserto': 'Desert Lagoon',
  'Framboesa Azul': 'Blue Raspberry',
  'Solar Marinho': 'Solar Navy',
  // Molduras e fundos embutidos
  'Transparente': 'Transparent',
  'Grafite': 'Graphite',
  'Titânio': 'Titanium',
  'Cerâmica': 'Ceramic',
  'Janela': 'Window',
  'Navegador': 'Browser',
  'Praia': 'Beach',
  'Montanhas': 'Mountains',
  'Coqueiros': 'Palm trees',
  'Nuvens': 'Clouds',
  // ShareTarget
  'Discord (grátis)': 'Discord (free)',
  'E-mail': 'Email',
  'Web rápida': 'Fast web',
};

/// [pt] traduzido pelo [modelTranslations] quando o app está em inglês.
String trKey(String pt) => tr(pt, modelTranslations[pt] ?? pt);
