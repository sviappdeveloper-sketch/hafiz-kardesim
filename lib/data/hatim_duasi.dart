/// Hatim duası (Duâ-i Hatm-i Kur'ân): Arapça metin ve sade Türkçe anlamı.
/// Bölümler, mushaflardaki geleneksel hatim duasının anlam bütünlüğüne göre ayrılmıştır.
const hatimDuasiArabic = [
  'بِسْمِ اللّٰهِ الرَّحْمٰنِ الرَّحِيمِ',
  'اَلْحَمْدُ لِلّٰهِ رَبِّ الْعَالَمِينَ • وَالْعَاقِبَةُ لِلْمُتَّقِينَ • وَلَا عُدْوَانَ إِلَّا عَلَى الظَّالِمِينَ • '
      'وَالصَّلٰوةُ وَالسَّلَامُ عَلٰى رَسُولِنَا مُحَمَّدٍ وَآلِهِ وَصَحْبِهِ أَجْمَعِينَ',
  'رَبَّنَا تَقَبَّلْ مِنَّا إِنَّكَ أَنْتَ السَّمِيعُ الْعَلِيمُ • وَتُبْ عَلَيْنَا يَا مَوْلٰينَا إِنَّكَ أَنْتَ التَّوَّابُ الرَّحِيمُ • '
      'وَاهْدِنَا وَوَفِّقْنَا إِلَى الْحَقِّ وَإِلٰى طَرِيقٍ مُسْتَقِيمٍ • بِبَرَكَةِ الْقُرْآنِ الْعَظِيمِ • '
      'وَبِحُرْمَةِ مَنْ أَرْسَلْتَهُ رَحْمَةً لِلْعَالَمِينَ',
  'وَاعْفُ عَنَّا يَا كَرِيمُ • وَاعْفُ عَنَّا يَا رَحِيمُ • وَاغْفِرْ لَنَا ذُنُوبَنَا بِفَضْلِكَ وَكَرَمِكَ يَا أَكْرَمَ الْأَكْرَمِينَ',
  'اَللّٰهُمَّ زَيِّنَّا بِزِينَةِ الْقُرْآنِ • وَأَكْرِمْنَا بِكَرَامَةِ الْقُرْآنِ • وَشَرِّفْنَا بِشَرَافَةِ الْقُرْآنِ • '
      'وَأَلْبِسْنَا بِخِلْعَةِ الْقُرْآنِ • وَأَدْخِلْنَا الْجَنَّةَ بِشَفَاعَةِ الْقُرْآنِ • '
      'وَعَافِنَا مِنْ كُلِّ بَلَاءِ الدُّنْيَا وَعَذَابِ الْآخِرَةِ بِحُرْمَةِ الْقُرْآنِ • '
      'وَارْحَمْ جَمِيعَ أُمَّةِ مُحَمَّدٍ يَا رَحِيمُ يَا رَحْمٰنُ',
  'اَللّٰهُمَّ اجْعَلِ الْقُرْآنَ لَنَا فِي الدُّنْيَا قَرِينًا وَفِي الْقَبْرِ مُونِسًا وَفِي الْقِيٰمَةِ شَفِيعًا '
      'وَعَلَى الصِّرَاطِ نُورًا • وَإِلَى الْجَنَّةِ رَفِيقًا • وَمِنَ النَّارِ سِتْرًا وَحِجَابًا • '
      'وَإِلَى الْخَيْرَاتِ كُلِّهَا دَلِيلًا وَإِمَامًا بِفَضْلِكَ وَجُودِكَ وَكَرَمِكَ يَا كَرِيمُ',
  'اَللّٰهُمَّ اهْدِنَا بِهِدَايَةِ الْقُرْآنِ • وَنَجِّنَا مِنَ النِّيرَانِ بِكَرَامَةِ الْقُرْآنِ • '
      'وَارْفَعْ دَرَجَاتِنَا بِفَضِيلَةِ الْقُرْآنِ • وَكَفِّرْ عَنَّا سَيِّئَاتِنَا بِتِلَاوَةِ الْقُرْآنِ • '
      'يَا ذَا الْفَضْلِ وَالْإِحْسَانِ',
  'اَللّٰهُمَّ طَهِّرْ قُلُوبَنَا • وَاسْتُرْ عُيُوبَنَا • وَاشْفِ مَرْضٰينَا • وَاقْضِ دُيُونَنَا • وَبَيِّضْ وُجُوهَنَا • '
      'وَارْفَعْ دَرَجَاتِنَا • وَارْحَمْ آبَاءَنَا • وَاغْفِرْ أُمَّهَاتِنَا • وَأَصْلِحْ دِينَنَا وَدُنْيَانَا • '
      'وَشَتِّتْ شَمْلَ أَعْدَائِنَا • وَاحْفَظْ أَهْلَنَا وَأَمْوَالَنَا وَبِلَادَنَا مِنْ جَمِيعِ الْآفَاتِ وَالْأَمْرَاضِ وَالْبَلَايَا • '
      'وَثَبِّتْ أَقْدَامَنَا وَانْصُرْنَا عَلَى الْقَوْمِ الْكَافِرِينَ • بِحُرْمَةِ الْقُرْآنِ الْعَظِيمِ',
  'اَللّٰهُمَّ بَلِّغْ ثَوَابَ مَا قَرَأْنَاهُ • وَنُورَ مَا تَلَوْنَاهُ • إِلٰى رُوحِ سَيِّدِنَا مُحَمَّدٍ صَلَّى اللّٰهُ تَعَالٰى عَلَيْهِ وَسَلَّمَ • '
      'وَإِلٰى أَرْوَاحِ جَمِيعِ إِخْوَانِهِ مِنَ الْأَنْبِيَاءِ وَالْمُرْسَلِينَ • صَلَوَاتُ اللّٰهِ وَسَلَامُهُ عَلَيْهِمْ أَجْمَعِينَ • '
      'وَإِلٰى أَرْوَاحِ آلِهِ وَأَوْلَادِهِ وَأَزْوَاجِهِ وَأَصْحَابِهِ وَأَتْبَاعِهِ وَجَمِيعِ ذُرِّيَّاتِهِ '
      'رِضْوَانُ اللّٰهِ تَعَالٰى عَلَيْهِمْ أَجْمَعِينَ',
  'وَإِلٰى أَرْوَاحِ آبَائِنَا وَأُمَّهَاتِنَا وَإِخْوَانِنَا وَأَخَوَاتِنَا وَأَوْلَادِنَا وَأَقْرِبَائِنَا وَأَحِبَّائِنَا وَأَصْدِقَائِنَا • '
      'وَأَسَاتِيذِنَا • وَمَشَايِخِنَا • وَلِمَنْ كَانَ لَهُ حَقٌّ عَلَيْنَا • '
      'وَلِجَمِيعِ الْمُؤْمِنِينَ وَالْمُؤْمِنَاتِ وَالْمُسْلِمِينَ وَالْمُسْلِمَاتِ • اَلْأَحْيَاءِ مِنْهُمْ وَالْأَمْوَاتِ',
  'يَا قَاضِيَ الْحَاجَاتِ • وَيَا مُجِيبَ الدَّعَوَاتِ • اِسْتَجِبْ دُعَاءَنَا بِرَحْمَتِكَ يَا أَرْحَمَ الرَّاحِمِينَ • '
      'وَسَلَامٌ عَلَى الْمُرْسَلِينَ • وَالْحَمْدُ لِلّٰهِ رَبِّ الْعَالَمِينَ • اَلْفَاتِحَةُ',
];

const hatimDuasiMeaning = [
  'Rahmân ve Rahîm olan Allah\'ın adıyla.',
  'Hamd, âlemlerin Rabbi Allah\'a mahsustur. Güzel son, takva sahiplerinindir. Düşmanlık ancak zalimlere karşıdır. '
      'Salât ve selâm Peygamberimiz Muhammed\'e, âline ve bütün ashabına olsun.',
  'Rabbimiz! Bizden kabul eyle; şüphesiz sen işitensin, bilensin. Ey Mevlâmız, tövbelerimizi kabul eyle; şüphesiz sen '
      'tövbeleri çokça kabul eden, merhamet edensin. Yüce Kur\'an\'ın bereketi ve âlemlere rahmet olarak gönderdiğin '
      'Peygamber hürmetine bizi hakka ve dosdoğru yola ilet, muvaffak kıl.',
  'Ey Kerîm, bizi affet. Ey Rahîm, bizi affet. Ey cömertlerin en cömerdi, fazlın ve keremin ile günahlarımızı bağışla.',
  'Allah\'ım! Bizi Kur\'an\'ın ziynetiyle süsle, Kur\'an\'ın ikramıyla ikramda bulun, Kur\'an\'ın şerefiyle şereflendir, '
      'bize Kur\'an\'ın elbisesini giydir, Kur\'an\'ın şefaatiyle bizi cennete koy. Kur\'an hürmetine bizi dünyanın her '
      'belasından ve ahiret azabından koru. Ey Rahîm, ey Rahmân, Muhammed ümmetinin hepsine merhamet eyle.',
  'Allah\'ım! Kur\'an\'ı bize dünyada dost, kabirde yoldaş, kıyamette şefaatçi, sıratta nur, cennete giderken arkadaş, '
      'cehenneme karşı perde ve örtü, bütün hayırlara rehber ve önder eyle; fazlın, cömertliğin ve keremin ile, ey Kerîm.',
  'Allah\'ım! Kur\'an\'ın hidayetiyle bizi doğru yola ilet, Kur\'an\'ın ikramıyla bizi ateşten kurtar, Kur\'an\'ın '
      'faziletiyle derecelerimizi yükselt, Kur\'an tilavetiyle kötülüklerimizi ört; ey lütuf ve ihsan sahibi.',
  'Allah\'ım! Kalplerimizi temizle, ayıplarımızı ört, hastalarımıza şifa ver, borçlarımızı ödemeyi nasip et, yüzlerimizi '
      'ak eyle, derecelerimizi yükselt, babalarımıza merhamet et, annelerimizi bağışla, dinimizi ve dünyamızı ıslah et, '
      'düşmanlarımızın birliğini dağıt. Ailemizi, mallarımızı ve memleketimizi bütün afetlerden, hastalıklardan ve '
      'belalardan koru. Ayaklarımızı sabit kıl, kâfirler topluluğuna karşı bize yardım et; yüce Kur\'an hürmetine.',
  'Allah\'ım! Okuduğumuzun sevabını ve tilavet ettiğimizin nurunu Efendimiz Muhammed\'in (s.a.v.) ruhuna, peygamber '
      've resullerden bütün kardeşlerinin ruhlarına (Allah\'ın salât ve selâmı hepsinin üzerine olsun); âlinin, '
      'evlatlarının, eşlerinin, ashabının, ona uyanların ve bütün neslinin ruhlarına (Allah hepsinden razı olsun) ulaştır.',
  'Annelerimizin, babalarımızın, erkek ve kız kardeşlerimizin, çocuklarımızın, akrabalarımızın, sevdiklerimizin, '
      'dostlarımızın, hocalarımızın, büyüklerimizin, üzerimizde hakkı olanların ve dirisiyle ölüsüyle bütün mümin '
      've Müslüman erkeklerin ve kadınların ruhlarına da ulaştır.',
  'Ey ihtiyaçları gideren, ey duaları kabul eden! Rahmetinle duamızı kabul eyle, ey merhametlilerin en merhametlisi. '
      'Peygamberlere selam olsun. Hamd, âlemlerin Rabbi Allah\'a mahsustur. El-Fâtiha.',
];

const hatimDuasiNiyet =
    'Bu hatmi birlikte okuyan bütün kardeşlerimizin, geçmişlerimizin ve bütün müminlerin ruhlarına hediye eyle. '
    'Okuduğumuz cüzleri katında kabul eyle, bizleri Kur\'an\'la diriltip Kur\'an ehliyle haşreyle. Âmin.';
