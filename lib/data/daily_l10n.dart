/// Günün ayeti ve hadisinin İngilizce ve Arapça karşılıkları (daily_content.dart ile aynı sıra).
/// Arapçada ayetler uygulamadaki Kur'an metninden (sure, ayet aralığı) birebir alınır.

/// (sure, ilk ayet, son ayet)
const dailyAyahRefs = <(int, int, int)>[
  (2, 152, 152), (2, 153, 153), (2, 186, 186), (2, 286, 286), (3, 103, 103), (3, 139, 139), (5, 2, 2),
  (7, 204, 204), (8, 2, 2), (10, 57, 57), (13, 28, 28), (14, 7, 7), (16, 97, 97), (17, 9, 9), (17, 82, 82),
  (20, 114, 114), (25, 63, 63), (29, 45, 45), (31, 18, 18), (35, 29, 29), (39, 53, 53), (41, 34, 34),
  (49, 10, 10), (49, 13, 13), (54, 17, 17), (57, 16, 16), (65, 2, 2), (65, 3, 3), (73, 4, 4), (93, 5, 5),
  (94, 5, 6),
];

const dailyAyahsEn = <(String, String)>[
  ('So remember Me; I will remember you. Be grateful to Me and do not be ungrateful.', 'Al-Baqarah 2:152'),
  ('O you who believe, seek help through patience and prayer. Indeed, Allah is with the patient.', 'Al-Baqarah 2:153'),
  ('When My servants ask you about Me, I am indeed near. I answer the call of the caller when he calls upon Me.', 'Al-Baqarah 2:186'),
  ('Allah does not burden a soul beyond what it can bear.', 'Al-Baqarah 2:286'),
  ('Hold firmly together to the rope of Allah and do not be divided.', 'Āl ʿImrān 3:103'),
  ('Do not weaken and do not grieve; you will be superior if you are true believers.', 'Āl ʿImrān 3:139'),
  ('Cooperate in righteousness and piety, and do not cooperate in sin and aggression.', 'Al-Māʾidah 5:2'),
  ('When the Quran is recited, listen to it and be silent, so that you may receive mercy.', 'Al-Aʿrāf 7:204'),
  ('The believers are those whose hearts tremble when Allah is mentioned, and whose faith increases when His verses are recited to them.', 'Al-Anfāl 8:2'),
  ('O mankind, there has come to you instruction from your Lord, a healing for what is in the hearts, guidance and mercy for the believers.', 'Yūnus 10:57'),
  ('Surely, in the remembrance of Allah do hearts find rest.', 'Ar-Raʿd 13:28'),
  ('If you are grateful, I will surely increase you.', 'Ibrāhīm 14:7'),
  ('Whoever does righteousness, male or female, while being a believer, We will surely grant them a good life.', 'An-Naḥl 16:97'),
  ('Indeed, this Quran guides to that which is most upright.', 'Al-Isrāʾ 17:9'),
  ('We send down of the Quran that which is healing and mercy for the believers.', 'Al-Isrāʾ 17:82'),
  ('And say, "My Lord, increase me in knowledge."', 'Ṭā Hā 20:114'),
  ('The servants of the Most Merciful are those who walk upon the earth humbly.', 'Al-Furqān 25:63'),
  ('Recite what has been revealed to you of the Book and establish prayer. Indeed, prayer prohibits immorality and wrongdoing.', 'Al-ʿAnkabūt 29:45'),
  ('Do not turn your cheek away from people in contempt, nor walk upon the earth arrogantly.', 'Luqmān 31:18'),
  ('Those who recite the Book of Allah and establish prayer hope for a trade that will never perish.', 'Fāṭir 35:29'),
  ('Do not despair of the mercy of Allah. Indeed, Allah forgives all sins.', 'Az-Zumar 39:53'),
  ('Good and evil are not equal. Repel evil with that which is better.', 'Fuṣṣilat 41:34'),
  ('The believers are but brothers, so make peace between your brothers.', 'Al-Ḥujurāt 49:10'),
  ('The most noble of you in the sight of Allah is the most righteous of you.', 'Al-Ḥujurāt 49:13'),
  ('We have certainly made the Quran easy to remember. So is there anyone who will take heed?', 'Al-Qamar 54:17'),
  ('Has the time not come for the believers that their hearts should humble themselves at the remembrance of Allah?', 'Al-Ḥadīd 57:16'),
  ('Whoever is mindful of Allah, He will make for him a way out.', 'Aṭ-Ṭalāq 65:2'),
  ('Whoever relies upon Allah, He is sufficient for him.', 'Aṭ-Ṭalāq 65:3'),
  ('Recite the Quran slowly and distinctly.', 'Al-Muzzammil 73:4'),
  ('Your Lord is going to give you, and you will be satisfied.', 'Aḍ-Ḍuḥā 93:5'),
  ('Indeed, with hardship comes ease. Indeed, with hardship comes ease.', 'Ash-Sharḥ 94:5-6'),
];

const dailyHadithsEn = <(String, String)>[
  ('The best of you are those who learn the Quran and teach it.', 'Bukhārī'),
  ('Read the Quran, for it will come on the Day of Resurrection as an intercessor for its companions.', 'Muslim'),
  ('Whoever reads a letter from the Book of Allah receives a good deed, and a good deed is rewarded tenfold.', 'Tirmidhī'),
  ('The one skilled in the Quran is with the noble, righteous angels; and the one who recites it with difficulty has a double reward.', 'Bukhārī and Muslim'),
  ('No people gather to recite the Book of Allah and study it together, except that tranquility descends upon them and mercy covers them.', 'Muslim'),
  ('Actions are judged by intentions.', 'Bukhārī'),
  ('None of you truly believes until he loves for his brother what he loves for himself.', 'Bukhārī'),
  ('Make things easy and do not make them difficult; give glad tidings and do not drive people away.', 'Bukhārī'),
  ('The most beloved deeds to Allah are those done consistently, even if small.', 'Bukhārī'),
  ('A Muslim is the one from whose tongue and hand the Muslims are safe.', 'Bukhārī'),
  ('Your smile to your brother is charity.', 'Tirmidhī'),
  ('A good word is charity.', 'Bukhārī'),
  ('Whoever does not show mercy will not be shown mercy.', 'Bukhārī'),
  ('Whoever believes in Allah and the Last Day, let him speak good or remain silent.', 'Bukhārī'),
  ('The believer who reads the Quran is like a citron: its fragrance is pleasant and its taste is pleasant.', 'Bukhārī'),
  ('Do not turn your houses into graves. Satan flees from the house in which Sūrat al-Baqarah is recited.', 'Muslim'),
  ('One who has nothing of the Quran within him is like a ruined house.', 'Tirmidhī'),
  ('The strong one is not the one who overcomes others in wrestling, but the one who controls himself when angry.', 'Bukhārī'),
  ('Give gifts to one another, and you will love one another.', 'Bukhārī, al-Adab al-Mufrad'),
  ('The believer to the believer is like a building whose parts support one another.', 'Bukhārī'),
  ('Allah does not look at your appearance or your wealth, but He looks at your hearts and your deeds.', 'Muslim'),
  ('Supplication is worship itself.', 'Tirmidhī'),
  ('There are two blessings which many people lose: health and free time.', 'Bukhārī'),
  ('Whoever guides to good receives a reward like the one who does it.', 'Muslim'),
  ('Purity is half of faith.', 'Muslim'),
  ('Modesty is part of faith.', 'Bukhārī'),
  ('Allah is beautiful and loves beauty.', 'Muslim'),
  ('Whoever does not thank people has not thanked Allah.', 'Tirmidhī'),
  ('Whoever relieves a believer of a hardship of this world, Allah will relieve him of a hardship of the Day of Resurrection.', 'Muslim'),
  ('Charity does not decrease wealth.', 'Muslim'),
  ('It will be said to the companion of the Quran: "Read and ascend, and recite as you used to recite in the world."', 'Tirmidhī'),
];

const dailyHadithsAr = <(String, String)>[
  ('خَيْرُكُمْ مَنْ تَعَلَّمَ الْقُرْآنَ وَعَلَّمَهُ', 'رواه البخاري'),
  ('اقْرَءُوا الْقُرْآنَ فَإِنَّهُ يَأْتِي يَوْمَ الْقِيَامَةِ شَفِيعًا لِأَصْحَابِهِ', 'رواه مسلم'),
  ('مَنْ قَرَأَ حَرْفًا مِنْ كِتَابِ اللَّهِ فَلَهُ بِهِ حَسَنَةٌ، وَالْحَسَنَةُ بِعَشْرِ أَمْثَالِهَا', 'رواه الترمذي'),
  ('الْمَاهِرُ بِالْقُرْآنِ مَعَ السَّفَرَةِ الْكِرَامِ الْبَرَرَةِ، وَالَّذِي يَقْرَأُ الْقُرْآنَ وَيَتَتَعْتَعُ فِيهِ وَهُوَ عَلَيْهِ شَاقٌّ لَهُ أَجْرَانِ', 'متفق عليه'),
  ('مَا اجْتَمَعَ قَوْمٌ فِي بَيْتٍ مِنْ بُيُوتِ اللَّهِ يَتْلُونَ كِتَابَ اللَّهِ وَيَتَدَارَسُونَهُ بَيْنَهُمْ إِلَّا نَزَلَتْ عَلَيْهِمُ السَّكِينَةُ وَغَشِيَتْهُمُ الرَّحْمَةُ', 'رواه مسلم'),
  ('إِنَّمَا الْأَعْمَالُ بِالنِّيَّاتِ', 'رواه البخاري'),
  ('لَا يُؤْمِنُ أَحَدُكُمْ حَتَّى يُحِبَّ لِأَخِيهِ مَا يُحِبُّ لِنَفْسِهِ', 'رواه البخاري'),
  ('يَسِّرُوا وَلَا تُعَسِّرُوا، وَبَشِّرُوا وَلَا تُنَفِّرُوا', 'رواه البخاري'),
  ('أَحَبُّ الْأَعْمَالِ إِلَى اللَّهِ أَدْوَمُهَا وَإِنْ قَلَّ', 'رواه البخاري'),
  ('الْمُسْلِمُ مَنْ سَلِمَ الْمُسْلِمُونَ مِنْ لِسَانِهِ وَيَدِهِ', 'رواه البخاري'),
  ('تَبَسُّمُكَ فِي وَجْهِ أَخِيكَ لَكَ صَدَقَةٌ', 'رواه الترمذي'),
  ('الْكَلِمَةُ الطَّيِّبَةُ صَدَقَةٌ', 'رواه البخاري'),
  ('مَنْ لَا يَرْحَمْ لَا يُرْحَمْ', 'رواه البخاري'),
  ('مَنْ كَانَ يُؤْمِنُ بِاللَّهِ وَالْيَوْمِ الْآخِرِ فَلْيَقُلْ خَيْرًا أَوْ لِيَصْمُتْ', 'رواه البخاري'),
  ('مَثَلُ الْمُؤْمِنِ الَّذِي يَقْرَأُ الْقُرْآنَ كَمَثَلِ الْأُتْرُجَّةِ، رِيحُهَا طَيِّبٌ وَطَعْمُهَا طَيِّبٌ', 'رواه البخاري'),
  ('لَا تَجْعَلُوا بُيُوتَكُمْ مَقَابِرَ، إِنَّ الشَّيْطَانَ يَنْفِرُ مِنَ الْبَيْتِ الَّذِي تُقْرَأُ فِيهِ سُورَةُ الْبَقَرَةِ', 'رواه مسلم'),
  ('إِنَّ الَّذِي لَيْسَ فِي جَوْفِهِ شَيْءٌ مِنَ الْقُرْآنِ كَالْبَيْتِ الْخَرِبِ', 'رواه الترمذي'),
  ('لَيْسَ الشَّدِيدُ بِالصُّرَعَةِ، إِنَّمَا الشَّدِيدُ الَّذِي يَمْلِكُ نَفْسَهُ عِنْدَ الْغَضَبِ', 'رواه البخاري'),
  ('تَهَادَوْا تَحَابُّوا', 'رواه البخاري في الأدب المفرد'),
  ('الْمُؤْمِنُ لِلْمُؤْمِنِ كَالْبُنْيَانِ يَشُدُّ بَعْضُهُ بَعْضًا', 'رواه البخاري'),
  ('إِنَّ اللَّهَ لَا يَنْظُرُ إِلَى صُوَرِكُمْ وَأَمْوَالِكُمْ، وَلَكِنْ يَنْظُرُ إِلَى قُلُوبِكُمْ وَأَعْمَالِكُمْ', 'رواه مسلم'),
  ('الدُّعَاءُ هُوَ الْعِبَادَةُ', 'رواه الترمذي'),
  ('نِعْمَتَانِ مَغْبُونٌ فِيهِمَا كَثِيرٌ مِنَ النَّاسِ: الصِّحَّةُ وَالْفَرَاغُ', 'رواه البخاري'),
  ('مَنْ دَلَّ عَلَى خَيْرٍ فَلَهُ مِثْلُ أَجْرِ فَاعِلِهِ', 'رواه مسلم'),
  ('الطُّهُورُ شَطْرُ الْإِيمَانِ', 'رواه مسلم'),
  ('الْحَيَاءُ مِنَ الْإِيمَانِ', 'رواه البخاري'),
  ('إِنَّ اللَّهَ جَمِيلٌ يُحِبُّ الْجَمَالَ', 'رواه مسلم'),
  ('مَنْ لَا يَشْكُرِ النَّاسَ لَا يَشْكُرِ اللَّهَ', 'رواه الترمذي'),
  ('مَنْ نَفَّسَ عَنْ مُؤْمِنٍ كُرْبَةً مِنْ كُرَبِ الدُّنْيَا نَفَّسَ اللَّهُ عَنْهُ كُرْبَةً مِنْ كُرَبِ يَوْمِ الْقِيَامَةِ', 'رواه مسلم'),
  ('مَا نَقَصَتْ صَدَقَةٌ مِنْ مَالٍ', 'رواه مسلم'),
  ('يُقَالُ لِصَاحِبِ الْقُرْآنِ: اقْرَأْ وَارْتَقِ وَرَتِّلْ كَمَا كُنْتَ تُرَتِّلُ فِي الدُّنْيَا', 'رواه الترمذي'),
];

/// Hatim duasının İngilizce anlamı (hatim_duasi.dart ile aynı bölümler).
const hatimDuasiMeaningEn = [
  'In the name of Allah, the Most Gracious, the Most Merciful.',
  'All praise is due to Allah, Lord of the worlds. The good end belongs to the righteous, and there is no hostility except against the wrongdoers. '
      'Blessings and peace be upon our Messenger Muhammad, his family and all his companions.',
  'Our Lord, accept this from us; indeed You are the All-Hearing, the All-Knowing. Accept our repentance, O our Master; indeed You are the '
      'Accepter of repentance, the Most Merciful. Guide us and grant us success towards the truth and the straight path, by the blessing of '
      'the Glorious Quran and for the sake of the one You sent as a mercy to the worlds.',
  'Pardon us, O Most Generous; pardon us, O Most Merciful; and forgive our sins by Your grace and generosity, O Most Generous of the generous.',
  'O Allah, adorn us with the adornment of the Quran, honour us with the honour of the Quran, ennoble us with the nobility of the Quran, '
      'clothe us with the garment of the Quran, admit us into Paradise through the intercession of the Quran, and protect us from every '
      'trial of this world and the punishment of the Hereafter for the sake of the Quran. Have mercy on the whole nation of Muhammad, '
      'O Most Merciful, O Most Gracious.',
  'O Allah, make the Quran for us a companion in this world, a comforter in the grave, an intercessor on the Day of Resurrection, a light '
      'on the Bridge, a friend on the way to Paradise, a veil and a shield from the Fire, and a guide and leader to all good, by Your grace, '
      'bounty and generosity, O Most Generous.',
  'O Allah, guide us with the guidance of the Quran, save us from the Fire by the honour of the Quran, raise our ranks by the virtue of '
      'the Quran, and expiate our wrongs through the recitation of the Quran, O Possessor of grace and kindness.',
  'O Allah, purify our hearts, cover our faults, heal our sick, settle our debts, brighten our faces, raise our ranks, have mercy on our '
      'fathers, forgive our mothers, set right our religion and our worldly life, scatter the unity of our enemies, protect our families, '
      'our wealth and our lands from all calamities, illnesses and afflictions, make our feet firm and grant us victory over the '
      'disbelieving people, for the sake of the Glorious Quran.',
  'O Allah, convey the reward of what we have read and the light of what we have recited to the soul of our master Muhammad (peace and '
      'blessings be upon him), to the souls of all his brothers among the prophets and messengers (Allah\'s blessings and peace be upon them '
      'all), and to the souls of his family, children, wives, companions, followers and all his descendants (may Allah be pleased with them all).',
  'And to the souls of our fathers, mothers, brothers, sisters, children, relatives, loved ones and friends, our teachers and elders, '
      'those who have a right over us, and all believing and Muslim men and women, the living and the dead.',
  'O Fulfiller of needs, O Answerer of prayers, answer our supplication by Your mercy, O Most Merciful of the merciful. '
      'Peace be upon the messengers, and all praise is due to Allah, Lord of the worlds. Al-Fātiḥah.',
];

const hatimDuasiNiyetEn =
    'Accept this completion as a gift to the souls of all our brothers and sisters who read it together with us, to our departed ones '
    'and to all believers. Accept the parts we have read, resurrect us with the Quran and gather us with the people of the Quran. Āmīn.';

const hatimDuasiNiyetAr =
    'اللَّهُمَّ اجْعَلْ ثَوَابَ هَذِهِ الْخَتْمَةِ هَدِيَّةً إِلَى أَرْوَاحِ إِخْوَانِنَا الَّذِينَ قَرَؤُوهَا مَعَنَا، وَإِلَى أَمْوَاتِنَا وَجَمِيعِ الْمُؤْمِنِينَ، '
    'وَتَقَبَّلْ مِنَّا مَا قَرَأْنَاهُ، وَاجْعَلْنَا مِنْ أَهْلِ الْقُرْآنِ وَاحْشُرْنَا مَعَهُمْ. آمِين.';
