// شخصيتا المساعد: غنى (تظهر للمسجلين الذكور والشركات اللي تختارها) ويمان (يظهر للمسجلات الإناث)
// ignore_for_file: lines_longer_than_80_chars

const String kGhinaSvg = r'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 800" width="800" height="800">
  <defs>
    <clipPath id="c"><circle cx="400" cy="400" r="400"/></clipPath>
    <linearGradient id="hj" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#FBBF24"/><stop offset="1" stop-color="#F59E0B"/>
    </linearGradient>
  </defs>
  <g clip-path="url(#c)">
    <rect width="800" height="800" fill="#E6F4F2"/>
    <circle cx="640" cy="170" r="70" fill="#CDEBE7"/>
    <circle cx="150" cy="260" r="40" fill="#CDEBE7"/>
    <path d="M140 800 C150 640 250 575 400 575 C550 575 650 640 660 800 Z" fill="#0F766E"/>
    <path d="M330 585 L400 700 L470 585 Z" fill="#FFFFFF"/>
    <path d="M330 585 L372 690 L340 700 L300 600 Z" fill="#115E59"/>
    <path d="M470 585 L428 690 L460 700 L500 600 Z" fill="#115E59"/>
    <path d="M230 360 C230 205 310 145 400 145 C490 145 570 205 570 360 C570 470 545 560 480 610 L320 610 C255 560 230 470 230 360 Z" fill="url(#hj)"/>
    <path d="M300 600 C330 640 470 640 500 600 L480 560 C450 590 350 590 320 560 Z" fill="#D97706"/>
    <path d="M300 340 C300 260 345 220 400 220 C455 220 500 260 500 340 C500 430 460 500 400 500 C340 500 300 430 300 340 Z" fill="#F2C7A5"/>
    <path d="M285 345 C280 250 335 200 400 200 C465 200 520 250 515 345 C512 300 470 235 400 235 C330 235 288 300 285 345 Z" fill="#D97706"/>
    <path d="M292 330 C300 420 330 505 400 515 C470 505 500 420 508 330 C512 450 470 540 400 545 C330 540 288 450 292 330 Z" fill="#D97706" opacity=".9"/>
    <path d="M340 322 Q362 308 384 318" stroke="#5B3A29" stroke-width="7" fill="none" stroke-linecap="round"/>
    <path d="M416 318 Q438 308 460 322" stroke="#5B3A29" stroke-width="7" fill="none" stroke-linecap="round"/>
    <ellipse cx="362" cy="352" rx="13" ry="16" fill="#2B2118"/>
    <ellipse cx="438" cy="352" rx="13" ry="16" fill="#2B2118"/>
    <circle cx="367" cy="346" r="4.5" fill="#fff"/>
    <circle cx="443" cy="346" r="4.5" fill="#fff"/>
    <path d="M346 340 Q362 330 378 338" stroke="#2B2118" stroke-width="4" fill="none" stroke-linecap="round"/>
    <path d="M422 338 Q438 330 454 340" stroke="#2B2118" stroke-width="4" fill="none" stroke-linecap="round"/>
    <path d="M400 370 Q394 398 404 404" stroke="#D99A78" stroke-width="5" fill="none" stroke-linecap="round"/>
    <ellipse cx="338" cy="405" rx="20" ry="12" fill="#F59E8B" opacity=".45"/>
    <ellipse cx="462" cy="405" rx="20" ry="12" fill="#F59E8B" opacity=".45"/>
    <path d="M366 430 Q400 462 434 430 Q400 446 366 430 Z" fill="#B4534A"/>
    <path d="M372 433 Q400 444 428 433 Q400 440 372 433 Z" fill="#fff"/>
    <g transform="rotate(-8 520 690)">
      <rect x="440" y="620" width="170" height="125" rx="14" fill="#14212B"/>
      <rect x="452" y="632" width="146" height="101" rx="8" fill="#F4F6F8"/>
      <circle cx="510" cy="682" r="22" fill="#0F766E" opacity=".9"/>
      <circle cx="540" cy="682" r="22" fill="#F59E0B" opacity=".9"/>
    </g>
    <path d="M430 700 C445 680 475 675 490 690 C500 705 480 725 455 725 C440 725 428 715 430 700 Z" fill="#F2C7A5"/>
  </g>
</svg>''';

const String kYamanSvg = r'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 800" width="800" height="800">
  <defs>
    <clipPath id="c"><circle cx="400" cy="400" r="400"/></clipPath>
  </defs>
  <g clip-path="url(#c)">
    <rect width="800" height="800" fill="#FEF3C7"/>
    <circle cx="160" cy="180" r="70" fill="#FDE68A" opacity=".7"/>
    <circle cx="650" cy="280" r="40" fill="#FDE68A" opacity=".7"/>
    <path d="M130 800 C140 640 245 580 400 580 C555 580 660 640 670 800 Z" fill="#0F766E"/>
    <path d="M400 600 L400 800" stroke="#115E59" stroke-width="5"/>
    <circle cx="400" cy="660" r="6" fill="#E6F4F2"/>
    <circle cx="400" cy="720" r="6" fill="#E6F4F2"/>
    <path d="M355 480 L355 590 Q400 620 445 590 L445 480 Z" fill="#D9A17C"/>
    <path d="M340 570 L400 610 L370 650 L320 595 Z" fill="#115E59"/>
    <path d="M460 570 L400 610 L430 650 L480 595 Z" fill="#115E59"/>
    <ellipse cx="292" cy="360" rx="20" ry="32" fill="#E1AE8A"/>
    <ellipse cx="508" cy="360" rx="20" ry="32" fill="#E1AE8A"/>
    <path d="M298 330 C298 245 345 205 400 205 C455 205 502 245 502 330 C502 435 462 510 400 510 C338 510 298 435 298 330 Z" fill="#E8B48F"/>
    <path d="M300 370 C305 455 345 515 400 518 C455 515 495 455 500 370 C490 430 470 470 440 480 Q400 470 360 480 C330 470 310 430 300 370 Z" fill="#3A2A20" opacity=".55"/>
    <path d="M364 420 Q400 406 436 420 Q438 432 430 434 Q400 422 370 434 Q362 432 364 420 Z" fill="#3A2A20" opacity=".6"/>
    <path d="M290 330 C280 220 340 160 410 165 C480 165 525 215 512 330 C505 280 485 255 450 250 C420 265 360 262 330 245 C305 265 296 295 290 330 Z" fill="#2B2118"/>
    <path d="M330 245 C350 200 420 190 470 215 C440 205 380 210 330 245 Z" fill="#45362B"/>
    <path d="M338 315 Q362 302 386 312" stroke="#2B2118" stroke-width="9" fill="none" stroke-linecap="round"/>
    <path d="M414 312 Q438 302 462 315" stroke="#2B2118" stroke-width="9" fill="none" stroke-linecap="round"/>
    <ellipse cx="362" cy="348" rx="12" ry="14" fill="#2B2118"/>
    <ellipse cx="438" cy="348" rx="12" ry="14" fill="#2B2118"/>
    <circle cx="366" cy="343" r="4" fill="#fff"/>
    <circle cx="442" cy="343" r="4" fill="#fff"/>
    <path d="M400 362 Q392 395 405 402" stroke="#C48662" stroke-width="5" fill="none" stroke-linecap="round"/>
    <path d="M372 450 Q400 472 428 450" stroke="#7A3B30" stroke-width="7" fill="none" stroke-linecap="round"/>
    <g transform="translate(500 660)">
      <circle cx="0" cy="0" r="26" fill="#E6F4F2"/>
      <circle cx="-7" cy="0" r="11" fill="#0F766E"/>
      <circle cx="7" cy="0" r="11" fill="#F59E0B" opacity=".9"/>
    </g>
  </g>
</svg>''';

String assistantName(String who) => who == 'yaman' ? 'يمان' : 'غنى';
String assistantSvg(String who) => who == 'yaman' ? kYamanSvg : kGhinaSvg;
