-- Smiler: built-in fight plans for CD Timeline (Heroic and Mythic).
-- Boss casts, phases and the expected raid-damage curve per fight, built from Warcraft Logs kills.
-- No healer assignments: paste your own NSRT / Viserio / planner string and it sits on top.
-- Loaded by CD Timeline only when you need it.
SmilerFights = SmilerFights or {}
local F = SmilerFights

-- Nymrissa Wavecaller (Heroic), 45 boss casts
F[3379] = F[3379] or {}
F[3379][15] = [==[
EncounterID:3379;Difficulty:Heroic;Name:Nymrissa Wavecaller;
duration:460;
curve:dmg;step:5;unit:k;data:118,760,1346,1173,923,711,699,1151,1266,1969,1379,1119,1301,715,631,291,755,1815,1648,1707,947,823,1168,1241,2780,2416,2223,1992,781,1041,1160,1335,1624,786,999,585,504,203,604,1551,1409,1436,807,777,1182,932,965,308,151,292,224,756,1110,1396,1718,908,1125,752,629,568,793,1750,1602,1291,1277,874,1309,1183,1472,1726,151,292,224,756,1110,1396,1718,908,1125,752,629,568,793,1750,1602,1291,1277,874,1309,1183,1472,1726;
lanedef:boss;name:Boss (at hit);kind:boss;
ph:1;time:10;tag:BOSS;spellid:1260837;lane:boss;label:Abyssal Rain (raid, ~15 s);cd:0;major:0;
ph:1;time:23;tag:BOSS;spellid:1284015;lane:boss;label:Alluring Bubble;cd:0;major:0;
ph:1;time:29;tag:BOSS;spellid:1282937;lane:boss;label:Iceblade Flurry;cd:0;major:0;
ph:1;time:37;tag:BOSS;spellid:1313393;lane:boss;label:Chilling Frost;cd:0;major:0;
ph:1;time:43;tag:BOSS;spellid:1260837;lane:boss;label:Abyssal Rain (raid, ~15 s);cd:0;major:0;
ph:1;time:51;tag:BOSS;spellid:1282937;lane:boss;label:Iceblade Flurry;cd:0;major:0;
ph:1;time:73;tag:BOSS;spellid:1282937;lane:boss;label:Iceblade Flurry;cd:0;major:0;
ph:1;time:81;tag:BOSS;spellid:1313393;lane:boss;label:Chilling Frost;cd:0;major:0;
ph:1;time:87;tag:BOSS;spellid:1260837;lane:boss;label:Abyssal Rain (raid, ~15 s);cd:0;major:0;
ph:1;time:95;tag:BOSS;spellid:1282937;lane:boss;label:Iceblade Flurry;cd:0;major:0;
ph:1;time:111;tag:BOSS;spellid:1258673;lane:boss;label:Swirling Whirlpools;cd:0;major:0;
ph:1;time:120;tag:BOSS;spellid:1258150;lane:boss;label:Pop! (bubbles break);cd:0;major:0;
ph:1;time:133;tag:BOSS;spellid:1284015;lane:boss;label:Alluring Bubble;cd:0;major:0;
ph:1;time:139;tag:BOSS;spellid:1282937;lane:boss;label:Iceblade Flurry;cd:0;major:0;
ph:1;time:147;tag:BOSS;spellid:1313393;lane:boss;label:Chilling Frost;cd:0;major:0;
ph:1;time:153;tag:BOSS;spellid:1260837;lane:boss;label:Abyssal Rain (raid, ~15 s);cd:0;major:0;
ph:1;time:161;tag:BOSS;spellid:1282937;lane:boss;label:Iceblade Flurry;cd:0;major:0;
ph:1;time:183;tag:BOSS;spellid:1282937;lane:boss;label:Iceblade Flurry;cd:0;major:0;
ph:1;time:191;tag:BOSS;spellid:1313393;lane:boss;label:Chilling Frost;cd:0;major:0;
ph:1;time:197;tag:BOSS;spellid:1260837;lane:boss;label:Abyssal Rain (raid, ~15 s);cd:0;major:0;
ph:1;time:205;tag:BOSS;spellid:1282937;lane:boss;label:Iceblade Flurry;cd:0;major:0;
ph:1;time:221;tag:BOSS;spellid:1258673;lane:boss;label:Swirling Whirlpools;cd:0;major:0;
ph:1;time:230;tag:BOSS;spellid:1258150;lane:boss;label:Pop! (bubbles break);cd:0;major:0;
ph:1;time:243;tag:BOSS;spellid:1284015;lane:boss;label:Alluring Bubble;cd:0;major:0;
ph:1;time:249;tag:BOSS;spellid:1282937;lane:boss;label:Iceblade Flurry;cd:0;major:0;
ph:1;time:257;tag:BOSS;spellid:1313393;lane:boss;label:Chilling Frost;cd:0;major:0;
ph:1;time:263;tag:BOSS;spellid:1260837;lane:boss;label:Abyssal Rain (raid, ~15 s);cd:0;major:0;
ph:1;time:271;tag:BOSS;spellid:1282937;lane:boss;label:Iceblade Flurry;cd:0;major:0;
ph:1;time:293;tag:BOSS;spellid:1282937;lane:boss;label:Iceblade Flurry;cd:0;major:0;
ph:1;time:301;tag:BOSS;spellid:1313393;lane:boss;label:Chilling Frost;cd:0;major:0;
ph:1;time:307;tag:BOSS;spellid:1260837;lane:boss;label:Abyssal Rain (raid, ~15 s);cd:0;major:0;
ph:1;time:315;tag:BOSS;spellid:1282937;lane:boss;label:Iceblade Flurry;cd:0;major:0;
ph:1;time:331;tag:BOSS;spellid:1258673;lane:boss;label:Swirling Whirlpools;cd:0;major:0;
ph:1;time:340;tag:BOSS;spellid:1258150;lane:boss;label:Pop! (bubbles break);cd:0;major:0;
ph:1;time:353;tag:BOSS;spellid:1284015;lane:boss;label:Alluring Bubble;cd:0;major:0;
ph:1;time:359;tag:BOSS;spellid:1282937;lane:boss;label:Iceblade Flurry;cd:0;major:0;
ph:1;time:367;tag:BOSS;spellid:1313393;lane:boss;label:Chilling Frost;cd:0;major:0;
ph:1;time:373;tag:BOSS;spellid:1260837;lane:boss;label:Abyssal Rain (raid, ~15 s);cd:0;major:0;
ph:1;time:381;tag:BOSS;spellid:1282937;lane:boss;label:Iceblade Flurry;cd:0;major:0;
ph:1;time:403;tag:BOSS;spellid:1282937;lane:boss;label:Iceblade Flurry;cd:0;major:0;
ph:1;time:411;tag:BOSS;spellid:1313393;lane:boss;label:Chilling Frost;cd:0;major:0;
ph:1;time:417;tag:BOSS;spellid:1260837;lane:boss;label:Abyssal Rain (raid, ~15 s);cd:0;major:0;
ph:1;time:425;tag:BOSS;spellid:1282937;lane:boss;label:Iceblade Flurry;cd:0;major:0;
ph:1;time:441;tag:BOSS;spellid:1258673;lane:boss;label:Swirling Whirlpools;cd:0;major:0;
ph:1;time:450;tag:BOSS;spellid:1258150;lane:boss;label:Pop! (bubbles break);cd:0;major:0;
]==]

-- Nymrissa Wavecaller (Mythic), 97 boss casts
F[3379] = F[3379] or {}
F[3379][16] = [==[
EncounterID:3379;Difficulty:Mythic;Name:Nymrissa Wavecaller;
duration:560;
curve:dmg;step:5;unit:k;data:0,0,99,52,13,13,13,11,45,376,557,604,361,121,8,0,0,94,431,584,572,314,80,6,0,0,0,0,0,0,45,387,559,605,362,122,9,0,0,98,442,585,573,315,81,6,0,0,0,0,0,0,47,399,561,607,364,124,9,0,0,103,452,586,574,316,82,7,0,0,0,0,0,0,49,410,563,608,365,125,10,0,0,107,462,588,576,318,84,7,0,0,0,0,0,0,51,422,565,609,366,126,11,0,0,111,473,589,577,319,85,8,0;
curve:heal;step:5;unit:k;data:5,35,40,40,40,40,35,5,0,60,320,20,0,0,0,0,0,0,24,40,40,40,40,40,16,0,0,0,0,0,0,0,0,0,0,0,24,40,40,40,40,40,16,0,0,0,280,120,0,0,0,0,0,0,24,40,40,40,40,40,16,0,0,0,0,0,0,0,0,0,0,0,24,40,40,40,40,40,16,0,0,0,0,0,0,0,0,0,0,0,24,320,160,40,40,40,16,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0;
lanedef:boss;name:Boss;kind:boss;
ph:1;time:10;tag:BOSS;spellid:0;lane:boss;label:Abyssal Rain;cd:0;major:0;
ph:1;time:24;tag:BOSS;spellid:0;lane:boss;label:Murloc Wave;cd:0;major:0;
ph:1;time:30;tag:BOSS;spellid:0;lane:boss;label:Water Jet;cd:0;major:0;
ph:1;time:38;tag:BOSS;spellid:0;lane:boss;label:Chilling Frost;cd:0;major:0;
ph:1;time:43;tag:BOSS;spellid:0;lane:boss;label:Abyssal Rain;cd:0;major:0;
ph:1;time:44;tag:BOSS;spellid:0;lane:boss;label:Burst 3 orbs;cd:0;major:0;
ph:1;time:47;tag:BOSS;spellid:0;lane:boss;label:Burst 3 orbs;cd:0;major:0;
ph:1;time:50;tag:BOSS;spellid:0;lane:boss;label:Burst 3 orbs;cd:0;major:0;
ph:1;time:52;tag:BOSS;spellid:0;lane:boss;label:Water Jet;cd:0;major:0;
ph:1;time:53;tag:BOSS;spellid:0;lane:boss;label:Burst 3 orbs;cd:0;major:0;
ph:1;time:68;tag:BOSS;spellid:0;lane:boss;label:Murloc Wave;cd:0;major:0;
ph:1;time:73;tag:BOSS;spellid:0;lane:boss;label:Water Jet;cd:0;major:0;
ph:1;time:82;tag:BOSS;spellid:0;lane:boss;label:Chilling Frost;cd:0;major:0;
ph:1;time:87;tag:BOSS;spellid:0;lane:boss;label:Abyssal Rain;cd:0;major:0;
ph:1;time:88;tag:BOSS;spellid:0;lane:boss;label:Burst 3 orbs;cd:0;major:0;
ph:1;time:91;tag:BOSS;spellid:0;lane:boss;label:Burst 3 orbs;cd:0;major:0;
ph:1;time:94;tag:BOSS;spellid:0;lane:boss;label:Burst 3 orbs;cd:0;major:0;
ph:1;time:95;tag:BOSS;spellid:0;lane:boss;label:Water Jet;cd:0;major:0;
ph:1;time:97;tag:BOSS;spellid:0;lane:boss;label:Burst 3 orbs;cd:0;major:0;
ph:1;time:110;tag:BOSS;spellid:0;lane:boss;label:Swirling Whirlpools;cd:0;major:0;
ph:1;time:119;tag:BOSS;spellid:0;lane:boss;label:Pop!;cd:0;major:0;
ph:1;time:135;tag:BOSS;spellid:0;lane:boss;label:Murloc Wave;cd:0;major:0;
ph:1;time:140;tag:BOSS;spellid:0;lane:boss;label:Water Jet;cd:0;major:0;
ph:1;time:148;tag:BOSS;spellid:0;lane:boss;label:Chilling Frost;cd:0;major:0;
ph:1;time:153;tag:BOSS;spellid:0;lane:boss;label:Abyssal Rain;cd:0;major:0;
ph:1;time:154;tag:BOSS;spellid:0;lane:boss;label:Burst 3 orbs;cd:0;major:0;
ph:1;time:157;tag:BOSS;spellid:0;lane:boss;label:Burst 3 orbs;cd:0;major:0;
ph:1;time:160;tag:BOSS;spellid:0;lane:boss;label:Burst 3 orbs;cd:0;major:0;
ph:1;time:162;tag:BOSS;spellid:0;lane:boss;label:Water Jet;cd:0;major:0;
ph:1;time:163;tag:BOSS;spellid:0;lane:boss;label:Burst 3 orbs;cd:0;major:0;
ph:1;time:179;tag:BOSS;spellid:0;lane:boss;label:Murloc Wave;cd:0;major:0;
ph:1;time:184;tag:BOSS;spellid:0;lane:boss;label:Water Jet;cd:0;major:0;
ph:1;time:192;tag:BOSS;spellid:0;lane:boss;label:Chilling Frost;cd:0;major:0;
ph:1;time:197;tag:BOSS;spellid:0;lane:boss;label:Abyssal Rain;cd:0;major:0;
ph:1;time:198;tag:BOSS;spellid:0;lane:boss;label:Burst 3 orbs;cd:0;major:0;
ph:1;time:201;tag:BOSS;spellid:0;lane:boss;label:Burst 3 orbs;cd:0;major:0;
ph:1;time:204;tag:BOSS;spellid:0;lane:boss;label:Burst 3 orbs;cd:0;major:0;
ph:1;time:206;tag:BOSS;spellid:0;lane:boss;label:Water Jet;cd:0;major:0;
ph:1;time:207;tag:BOSS;spellid:0;lane:boss;label:Burst 3 orbs;cd:0;major:0;
ph:1;time:221;tag:BOSS;spellid:0;lane:boss;label:Swirling Whirlpools;cd:0;major:0;
ph:1;time:230;tag:BOSS;spellid:0;lane:boss;label:Pop!;cd:0;major:0;
ph:1;time:245;tag:BOSS;spellid:0;lane:boss;label:Murloc Wave;cd:0;major:0;
ph:1;time:250;tag:BOSS;spellid:0;lane:boss;label:Water Jet;cd:0;major:0;
ph:1;time:258;tag:BOSS;spellid:0;lane:boss;label:Chilling Frost;cd:0;major:0;
ph:1;time:263;tag:BOSS;spellid:0;lane:boss;label:Abyssal Rain;cd:0;major:0;
ph:1;time:264;tag:BOSS;spellid:0;lane:boss;label:Burst 3 orbs;cd:0;major:0;
ph:1;time:267;tag:BOSS;spellid:0;lane:boss;label:Burst 3 orbs;cd:0;major:0;
ph:1;time:270;tag:BOSS;spellid:0;lane:boss;label:Burst 3 orbs;cd:0;major:0;
ph:1;time:272;tag:BOSS;spellid:0;lane:boss;label:Water Jet;cd:0;major:0;
ph:1;time:273;tag:BOSS;spellid:0;lane:boss;label:Burst 3 orbs;cd:0;major:0;
ph:1;time:289;tag:BOSS;spellid:0;lane:boss;label:Murloc Wave;cd:0;major:0;
ph:1;time:294;tag:BOSS;spellid:0;lane:boss;label:Water Jet;cd:0;major:0;
ph:1;time:302;tag:BOSS;spellid:0;lane:boss;label:Chilling Frost;cd:0;major:0;
ph:1;time:307;tag:BOSS;spellid:0;lane:boss;label:Abyssal Rain;cd:0;major:0;
ph:1;time:308;tag:BOSS;spellid:0;lane:boss;label:Burst 3 orbs;cd:0;major:0;
ph:1;time:311;tag:BOSS;spellid:0;lane:boss;label:Burst 3 orbs;cd:0;major:0;
ph:1;time:314;tag:BOSS;spellid:0;lane:boss;label:Burst 3 orbs;cd:0;major:0;
ph:1;time:316;tag:BOSS;spellid:0;lane:boss;label:Water Jet;cd:0;major:0;
ph:1;time:317;tag:BOSS;spellid:0;lane:boss;label:Burst 3 orbs;cd:0;major:0;
ph:1;time:331;tag:BOSS;spellid:0;lane:boss;label:Swirling Whirlpools;cd:0;major:0;
ph:1;time:340;tag:BOSS;spellid:0;lane:boss;label:Pop!;cd:0;major:0;
ph:1;time:355;tag:BOSS;spellid:0;lane:boss;label:Murloc Wave;cd:0;major:0;
ph:1;time:360;tag:BOSS;spellid:0;lane:boss;label:Water Jet;cd:0;major:0;
ph:1;time:368;tag:BOSS;spellid:0;lane:boss;label:Chilling Frost;cd:0;major:0;
ph:1;time:373;tag:BOSS;spellid:0;lane:boss;label:Abyssal Rain;cd:0;major:0;
ph:1;time:374;tag:BOSS;spellid:0;lane:boss;label:Burst 3 orbs;cd:0;major:0;
ph:1;time:377;tag:BOSS;spellid:0;lane:boss;label:Burst 3 orbs;cd:0;major:0;
ph:1;time:380;tag:BOSS;spellid:0;lane:boss;label:Burst 3 orbs;cd:0;major:0;
ph:1;time:382;tag:BOSS;spellid:0;lane:boss;label:Water Jet;cd:0;major:0;
ph:1;time:383;tag:BOSS;spellid:0;lane:boss;label:Burst 3 orbs;cd:0;major:0;
ph:1;time:399;tag:BOSS;spellid:0;lane:boss;label:Murloc Wave;cd:0;major:0;
ph:1;time:404;tag:BOSS;spellid:0;lane:boss;label:Water Jet;cd:0;major:0;
ph:1;time:412;tag:BOSS;spellid:0;lane:boss;label:Chilling Frost;cd:0;major:0;
ph:1;time:417;tag:BOSS;spellid:0;lane:boss;label:Abyssal Rain;cd:0;major:0;
ph:1;time:418;tag:BOSS;spellid:0;lane:boss;label:Burst 3 orbs;cd:0;major:0;
ph:1;time:421;tag:BOSS;spellid:0;lane:boss;label:Burst 3 orbs;cd:0;major:0;
ph:1;time:424;tag:BOSS;spellid:0;lane:boss;label:Burst 3 orbs;cd:0;major:0;
ph:1;time:426;tag:BOSS;spellid:0;lane:boss;label:Water Jet;cd:0;major:0;
ph:1;time:427;tag:BOSS;spellid:0;lane:boss;label:Burst 3 orbs;cd:0;major:0;
ph:1;time:441;tag:BOSS;spellid:0;lane:boss;label:Swirling Whirlpools;cd:0;major:0;
ph:1;time:450;tag:BOSS;spellid:0;lane:boss;label:Pop!;cd:0;major:0;
ph:1;time:470;tag:BOSS;spellid:0;lane:boss;label:Water Jet;cd:0;major:0;
ph:1;time:478;tag:BOSS;spellid:0;lane:boss;label:Chilling Frost;cd:0;major:0;
ph:1;time:483;tag:BOSS;spellid:0;lane:boss;label:Abyssal Rain;cd:0;major:0;
ph:1;time:484;tag:BOSS;spellid:0;lane:boss;label:Burst 3 orbs;cd:0;major:0;
ph:1;time:487;tag:BOSS;spellid:0;lane:boss;label:Burst 3 orbs;cd:0;major:0;
ph:1;time:490;tag:BOSS;spellid:0;lane:boss;label:Burst 3 orbs;cd:0;major:0;
ph:1;time:492;tag:BOSS;spellid:0;lane:boss;label:Water Jet;cd:0;major:0;
ph:1;time:493;tag:BOSS;spellid:0;lane:boss;label:Burst 3 orbs;cd:0;major:0;
ph:1;time:514;tag:BOSS;spellid:0;lane:boss;label:Water Jet;cd:0;major:0;
ph:1;time:522;tag:BOSS;spellid:0;lane:boss;label:Chilling Frost;cd:0;major:0;
ph:1;time:527;tag:BOSS;spellid:0;lane:boss;label:Abyssal Rain;cd:0;major:0;
ph:1;time:528;tag:BOSS;spellid:0;lane:boss;label:Burst 3 orbs;cd:0;major:0;
ph:1;time:531;tag:BOSS;spellid:0;lane:boss;label:Burst 3 orbs;cd:0;major:0;
ph:1;time:534;tag:BOSS;spellid:0;lane:boss;label:Burst 3 orbs;cd:0;major:0;
ph:1;time:536;tag:BOSS;spellid:0;lane:boss;label:Water Jet;cd:0;major:0;
ph:1;time:537;tag:BOSS;spellid:0;lane:boss;label:Burst 3 orbs;cd:0;major:0;
]==]

-- Sszorak (Heroic), 27 boss casts
F[3420] = F[3420] or {}
F[3420][15] = [==[
EncounterID:3420;Difficulty:Heroic;Name:Sszorak;
duration:264;
curve:dmg;step:5;unit:k;data:428,1005,1227,1207,1585,1709,1409,1313,1576,1402,903,957,1282,1231,1295,1635,1478,1192,1361,1594,1357,760,1091,1403,1336,1337,1300,1507,1386,1022,1028,1086,1481,1702,1744,1603,1548,1345,848,672,1106,1536,1820,1858,1587,1281,1384,1305,946,840,1041,1267,861;
lanedef:boss;name:Boss;kind:boss;
ph:1;time:5.6;tag:BOSS;spellid:1277027;lane:boss;label:Mutilate (3 s);cd:0;major:0;
ph:1;time:9.6;tag:BOSS;spellid:1277002;lane:boss;label:Ravage (3 s);cd:0;major:0;
ph:1;time:17.6;tag:BOSS;spellid:1287072;lane:boss;label:Tempest (4 s);cd:0;major:0;
ph:1;time:22.1;tag:BOSS;spellid:1277027;lane:boss;label:Mutilate (3 s);cd:0;major:0;
ph:1;time:32.2;tag:BOSS;spellid:1305959;lane:boss;label:Venomous Surge;cd:0;major:0;
ph:1;time:43.3;tag:BOSS;spellid:1285425;lane:boss;label:Raging Crosswinds;cd:0;major:0;
ph:1;time:57.8;tag:BOSS;spellid:1277027;lane:boss;label:Mutilate (3 s);cd:0;major:0;
ph:1;time:61.8;tag:BOSS;spellid:1277002;lane:boss;label:Ravage (3 s);cd:0;major:0;
ph:1;time:69.8;tag:BOSS;spellid:1287072;lane:boss;label:Tempest (4 s);cd:0;major:0;
ph:1;time:74.3;tag:BOSS;spellid:1277027;lane:boss;label:Mutilate (3 s);cd:0;major:0;
ph:1;time:84.5;tag:BOSS;spellid:1305959;lane:boss;label:Venomous Surge;cd:0;major:0;
ph:1;time:95.5;tag:BOSS;spellid:1285425;lane:boss;label:Raging Crosswinds;cd:0;major:0;
ph:1;time:111.2;tag:BOSS;spellid:1286033;lane:boss;label:Dig In;cd:0;major:0;
ph:1;time:143.7;tag:BOSS;spellid:1277027;lane:boss;label:Mutilate (3 s);cd:0;major:0;
ph:1;time:147.7;tag:BOSS;spellid:1277002;lane:boss;label:Ravage (3 s);cd:0;major:0;
ph:1;time:151.7;tag:BOSS;spellid:1287072;lane:boss;label:Tempest (4 s);cd:0;major:0;
ph:1;time:156.2;tag:BOSS;spellid:1277002;lane:boss;label:Ravage (3 s);cd:0;major:0;
ph:1;time:160.2;tag:BOSS;spellid:1277027;lane:boss;label:Mutilate (3 s);cd:0;major:0;
ph:1;time:170.4;tag:BOSS;spellid:1305959;lane:boss;label:Venomous Surge;cd:0;major:0;
ph:1;time:181.5;tag:BOSS;spellid:1285425;lane:boss;label:Raging Crosswinds;cd:0;major:0;
ph:1;time:195.9;tag:BOSS;spellid:1277002;lane:boss;label:Ravage (3 s);cd:0;major:0;
ph:1;time:199.9;tag:BOSS;spellid:1277027;lane:boss;label:Mutilate (3 s);cd:0;major:0;
ph:1;time:207.9;tag:BOSS;spellid:1287072;lane:boss;label:Tempest (4 s);cd:0;major:0;
ph:1;time:212.4;tag:BOSS;spellid:1277002;lane:boss;label:Ravage (3 s);cd:0;major:0;
ph:1;time:222.6;tag:BOSS;spellid:1305959;lane:boss;label:Venomous Surge;cd:0;major:0;
ph:1;time:233.7;tag:BOSS;spellid:1285425;lane:boss;label:Raging Crosswinds;cd:0;major:0;
ph:1;time:249.3;tag:BOSS;spellid:1286033;lane:boss;label:Dig In;cd:0;major:0;
]==]

-- The Twin Fangs (Heroic), 33 boss casts
F[3421] = F[3421] or {}
F[3421][15] = [==[
EncounterID:3421;Difficulty:Heroic;Name:The Twin Fangs;
duration:356;
curve:dmg;step:5;unit:k;data:442,821,987,996,910,794,818,857,988,1399,1796,1762,1401,1013,1093,1195,1213,1108,915,869,968,1009,1296,1658,1819,1506,1287,1185,1085,921,881,903,952,1009,1151,1289,1404,1301,1148,1066,1140,1237,1354,1679,1921,1814,1583,1243,1293,1385,1498,1389,1154,1093,1170,1315,1767,2070,2134,1748,1425,1283,1224,1181,1177,1139,1136,1125,1180,1300,990,725;
lanedef:boss;name:Boss;kind:boss;
ph:1;time:8.9;tag:BOSS;spellid:1289192;lane:boss;label:Caustic Deluge;cd:0;major:0;
ph:1;time:25;tag:BOSS;spellid:1289092;lane:boss;label:Stone Breaker (2 s);cd:0;major:0;
ph:1;time:36.6;tag:BOSS;spellid:1291404;lane:boss;label:Venomous Emergence (3 s);cd:0;major:0;
ph:1;time:41.7;tag:BOSS;spellid:1291478;lane:boss;label:Corrosive Spit (5 s);cd:0;major:0;
ph:1;time:44.4;tag:BOSS;spellid:1290809;lane:boss;label:Coiling Ichor (3 s);cd:0;major:0;
ph:1;time:52.2;tag:BOSS;spellid:1290956;lane:boss;label:Stir the Depths;cd:0;major:0;
ph:1;time:63.3;tag:BOSS;spellid:1290516;lane:boss;label:Ravenous Feast (4 s);cd:0;major:0;
ph:1;time:76.7;tag:BOSS;spellid:1289192;lane:boss;label:Caustic Deluge;cd:0;major:0;
ph:1;time:92.8;tag:BOSS;spellid:1289092;lane:boss;label:Stone Breaker;cd:0;major:0;
ph:1;time:104.4;tag:BOSS;spellid:1291404;lane:boss;label:Venomous Emergence (3 s);cd:0;major:0;
ph:1;time:112.2;tag:BOSS;spellid:1290809;lane:boss;label:Coiling Ichor (3 s);cd:0;major:0;
ph:1;time:120;tag:BOSS;spellid:1290956;lane:boss;label:Stir the Depths;cd:0;major:0;
ph:1;time:131.2;tag:BOSS;spellid:1290516;lane:boss;label:Ravenous Feast (4 s);cd:0;major:0;
ph:1;time:150.4;tag:BOSS;spellid:1306872;lane:boss;label:Sanguine Storm;cd:0;major:0;
ph:1;time:150.5;tag:BOSS;spellid:1294293;lane:boss;label:Vile Flood (4 s);cd:0;major:0;
ph:1;time:173.9;tag:BOSS;spellid:1295107;lane:boss;label:Concentrated Spittle;cd:0;major:0;
ph:1;time:178.4;tag:BOSS;spellid:1289192;lane:boss;label:Caustic Deluge;cd:0;major:0;
ph:1;time:194.5;tag:BOSS;spellid:1289092;lane:boss;label:Stone Breaker (2 s);cd:0;major:0;
ph:1;time:206.2;tag:BOSS;spellid:1291404;lane:boss;label:Venomous Emergence (3 s);cd:0;major:0;
ph:1;time:210.2;tag:BOSS;spellid:1291478;lane:boss;label:Corrosive Spit (5 s);cd:0;major:0;
ph:1;time:213.9;tag:BOSS;spellid:1290809;lane:boss;label:Coiling Ichor (3 s);cd:0;major:0;
ph:1;time:221.7;tag:BOSS;spellid:1290956;lane:boss;label:Stir the Depths;cd:0;major:0;
ph:1;time:232.8;tag:BOSS;spellid:1290516;lane:boss;label:Ravenous Feast (4 s);cd:0;major:0;
ph:1;time:246.2;tag:BOSS;spellid:1289192;lane:boss;label:Caustic Deluge;cd:0;major:0;
ph:1;time:262.2;tag:BOSS;spellid:1289092;lane:boss;label:Stone Breaker;cd:0;major:0;
ph:1;time:273.9;tag:BOSS;spellid:1291404;lane:boss;label:Venomous Emergence (3 s);cd:0;major:0;
ph:1;time:278;tag:BOSS;spellid:1291478;lane:boss;label:Corrosive Spit (5 s);cd:0;major:0;
ph:1;time:281.7;tag:BOSS;spellid:1290809;lane:boss;label:Coiling Ichor (3 s);cd:0;major:0;
ph:1;time:289.5;tag:BOSS;spellid:1290956;lane:boss;label:Stir the Depths;cd:0;major:0;
ph:1;time:300.6;tag:BOSS;spellid:1290516;lane:boss;label:Ravenous Feast (4 s);cd:0;major:0;
ph:1;time:319.9;tag:BOSS;spellid:1294293;lane:boss;label:Vile Flood (4 s);cd:0;major:0;
ph:1;time:319.9;tag:BOSS;spellid:1306872;lane:boss;label:Sanguine Storm;cd:0;major:0;
ph:1;time:347.9;tag:BOSS;spellid:1289192;lane:boss;label:Caustic Deluge;cd:0;major:0;
]==]

-- The Coiled Altar (Heroic), 39 boss casts
F[3429] = F[3429] or {}
F[3429][15] = [==[
EncounterID:3429;Difficulty:Heroic;Name:The Coiled Altar;
duration:336;
curve:dmg;step:5;unit:k;data:638,889,882,813,1094,1350,1218,956,850,1333,1510,1468,1400,1358,1227,1018,1249,1375,1336,1553,1868,2033,1577,1103,1118,1195,1300,1399,1605,1557,1253,1142,1192,1194,1309,1287,1193,899,490,386,905,1758,2711,2747,2304,1151,664,463,575,835,1068,1327,1415,1464,1420,1278,1112,1101,1281,1448,1581,1651,1492,1226,1050,873,557,344;
lanedef:boss;name:Boss;kind:boss;
ph:1;time:0;tag:BOSS;spellid:1282487;lane:boss;label:Fangs of the Coiled Altar;cd:0;major:0;
ph:1;time:2;tag:BOSS;spellid:1299960;lane:boss;label:Toxic Deluge;cd:0;major:0;
ph:1;time:7.9;tag:BOSS;spellid:1283290;lane:boss;label:Noxious Ground;cd:0;major:0;
ph:1;time:12;tag:BOSS;spellid:1285017;lane:boss;label:Axegrinder (2 s);cd:0;major:0;
ph:1;time:20;tag:BOSS;spellid:1299684;lane:boss;label:Sever (3 s);cd:0;major:0;
ph:1;time:28;tag:BOSS;spellid:1282287;lane:boss;label:Venomfang (2 s);cd:0;major:0;
ph:1;time:37;tag:BOSS;spellid:1299684;lane:boss;label:Sever (3 s);cd:0;major:0;
ph:1;time:43;tag:BOSS;spellid:1283485;lane:boss;label:Guillotine (4 s);cd:0;major:0;
ph:1;time:45;tag:BOSS;spellid:1299960;lane:boss;label:Toxic Deluge;cd:0;major:0;
ph:1;time:57;tag:BOSS;spellid:1299684;lane:boss;label:Sever (3 s);cd:0;major:0;
ph:1;time:63;tag:BOSS;spellid:1282287;lane:boss;label:Venomfang (2 s);cd:0;major:0;
ph:1;time:74;tag:BOSS;spellid:1299684;lane:boss;label:Sever (3 s);cd:0;major:0;
ph:1;time:85;tag:BOSS;spellid:1282487;lane:boss;label:Fangs of the Coiled Altar;cd:0;major:0;
ph:1;time:87;tag:BOSS;spellid:1299960;lane:boss;label:Toxic Deluge;cd:0;major:0;
ph:1;time:97;tag:BOSS;spellid:1285017;lane:boss;label:Axegrinder (2 s);cd:0;major:0;
ph:1;time:107.5;tag:BOSS;spellid:1288624;lane:boss;label:Dreadful Presence;cd:0;major:0;
ph:1;time:113;tag:BOSS;spellid:1285643;lane:boss;label:Dreadmarch (2 s);cd:0;major:0;
ph:1;time:120.5;tag:BOSS;spellid:1286441;lane:boss;label:Spiritcackle;cd:0;major:0;
ph:1;time:125;tag:BOSS;spellid:1308311;lane:boss;label:Retaliatory Malice;cd:0;major:0;
ph:1;time:129.5;tag:BOSS;spellid:1310882;lane:boss;label:Gloombomb (2 s);cd:0;major:0;
ph:1;time:132.7;tag:BOSS;spellid:1286399;lane:boss;label:Wail of Terror;cd:0;major:0;
ph:1;time:141.5;tag:BOSS;spellid:1286620;lane:boss;label:Soul Sever (4 s);cd:0;major:0;
ph:1;time:149.6;tag:BOSS;spellid:1285643;lane:boss;label:Dreadmarch (2 s);cd:0;major:0;
ph:1;time:153.5;tag:BOSS;spellid:1286441;lane:boss;label:Spiritcackle;cd:0;major:0;
ph:1;time:158;tag:BOSS;spellid:1308311;lane:boss;label:Retaliatory Malice;cd:0;major:0;
ph:1;time:167.5;tag:BOSS;spellid:1310882;lane:boss;label:Gloombomb (2 s);cd:0;major:0;
ph:1;time:172.5;tag:BOSS;spellid:1286620;lane:boss;label:Soul Sever (4 s);cd:0;major:0;
ph:1;time:192.9;tag:BOSS;spellid:1304028;lane:boss;label:Deathguard;cd:0;major:0;
ph:1;time:195.4;tag:BOSS;spellid:1304032;lane:boss;label:Soulbinding;cd:0;major:0;
ph:1;time:195.6;tag:BOSS;spellid:1304498;lane:boss;label:Ghastly Regeneration;cd:0;major:0;
ph:1;time:233.1;tag:BOSS;spellid:1298381;lane:boss;label:Defilement of the Coiled Altar;cd:0;major:0;
ph:1;time:235.4;tag:BOSS;spellid:1299960;lane:boss;label:Toxic Deluge;cd:0;major:0;
ph:1;time:250.4;tag:BOSS;spellid:1299266;lane:boss;label:Grim Guillotine (4 s);cd:0;major:0;
ph:1;time:259.6;tag:BOSS;spellid:1310882;lane:boss;label:Gloombomb (2 s);cd:0;major:0;
ph:1;time:266.4;tag:BOSS;spellid:1307292;lane:boss;label:Blighted Sever (3 s);cd:0;major:0;
ph:1;time:282.5;tag:BOSS;spellid:1299960;lane:boss;label:Toxic Deluge;cd:0;major:0;
ph:1;time:294.1;tag:BOSS;spellid:1285643;lane:boss;label:Dreadmarch (2 s);cd:0;major:0;
ph:1;time:298.7;tag:BOSS;spellid:1307292;lane:boss;label:Blighted Sever (3 s);cd:0;major:0;
ph:1;time:310.1;tag:BOSS;spellid:1310882;lane:boss;label:Gloombomb (2 s);cd:0;major:0;
]==]

-- Entombed Sentinels (Heroic), 46 boss casts
F[3445] = F[3445] or {}
F[3445][15] = [==[
EncounterID:3445;Difficulty:Heroic;Name:Entombed Sentinels;
duration:265;
curve:dmg;step:5;unit:k;data:91,179,267,690,1238,1142,808,600,533,544,587,553,682,745,1005,1323,1501,1355,1039,779,767,1095,1097,804,1055,1475,1518,1440,1227,1076,976,1009,1074,1235,1302,1613,1651,1342,1309,993,617,1005,1124,925,866,1098,1401,1464,1311,1182,928,874,632;
lanedef:boss;name:Boss;kind:boss;
ph:1;time:4.7;tag:BOSS;spellid:1284458;lane:boss;label:Empowering Slam (2 s);cd:0;major:0;
ph:1;time:7.1;tag:BOSS;spellid:1284487;lane:boss;label:Bloodvenom Injection;cd:0;major:0;
ph:1;time:10.8;tag:BOSS;spellid:1284251;lane:boss;label:Venom Coagulation (2 s);cd:0;major:0;
ph:1;time:13.2;tag:BOSS;spellid:1284434;lane:boss;label:Toxic Droplets (2 s);cd:0;major:0;
ph:1;time:16.8;tag:BOSS;spellid:1288232;lane:boss;label:Unstable Miasma;cd:0;major:0;
ph:1;time:18.1;tag:BOSS;spellid:1284257;lane:boss;label:Contaminate;cd:0;major:0;
ph:1;time:26.5;tag:BOSS;spellid:1284458;lane:boss;label:Empowering Slam;cd:0;major:0;
ph:1;time:29;tag:BOSS;spellid:1284487;lane:boss;label:Bloodvenom Injection (2 s);cd:0;major:0;
ph:1;time:41.1;tag:BOSS;spellid:1284483;lane:boss;label:Blighted Blood (2 s);cd:0;major:0;
ph:1;time:46.3;tag:BOSS;spellid:1284606;lane:boss;label:Vitriolic Stasis;cd:0;major:0;
ph:1;time:61.8;tag:BOSS;spellid:1284458;lane:boss;label:Empowering Slam (2 s);cd:0;major:0;
ph:1;time:64.3;tag:BOSS;spellid:1284487;lane:boss;label:Bloodvenom Injection;cd:0;major:0;
ph:1;time:67.9;tag:BOSS;spellid:1284251;lane:boss;label:Venom Coagulation;cd:0;major:0;
ph:1;time:70.3;tag:BOSS;spellid:1284434;lane:boss;label:Toxic Droplets (2 s);cd:0;major:0;
ph:1;time:74;tag:BOSS;spellid:1288232;lane:boss;label:Unstable Miasma;cd:0;major:0;
ph:1;time:75.2;tag:BOSS;spellid:1284257;lane:boss;label:Contaminate;cd:0;major:0;
ph:1;time:83.7;tag:BOSS;spellid:1284458;lane:boss;label:Empowering Slam;cd:0;major:0;
ph:1;time:86.1;tag:BOSS;spellid:1284487;lane:boss;label:Bloodvenom Injection (2 s);cd:0;major:0;
ph:1;time:98.3;tag:BOSS;spellid:1284483;lane:boss;label:Blighted Blood (2 s);cd:0;major:0;
ph:1;time:103.1;tag:BOSS;spellid:1284434;lane:boss;label:Toxic Droplets (2 s);cd:0;major:0;
ph:1;time:105.6;tag:BOSS;spellid:1284458;lane:boss;label:Empowering Slam (2 s);cd:0;major:0;
ph:1;time:108;tag:BOSS;spellid:1284487;lane:boss;label:Bloodvenom Injection;cd:0;major:0;
ph:1;time:115.3;tag:BOSS;spellid:1288232;lane:boss;label:Unstable Miasma;cd:0;major:0;
ph:1;time:120.1;tag:BOSS;spellid:1284251;lane:boss;label:Venom Coagulation (2 s);cd:0;major:0;
ph:1;time:127.4;tag:BOSS;spellid:1284458;lane:boss;label:Empowering Slam (2 s);cd:0;major:0;
ph:1;time:127.4;tag:BOSS;spellid:1284257;lane:boss;label:Contaminate;cd:0;major:0;
ph:1;time:129.9;tag:BOSS;spellid:1284487;lane:boss;label:Bloodvenom Injection (2 s);cd:0;major:0;
ph:1;time:148.4;tag:BOSS;spellid:1284606;lane:boss;label:Vitriolic Stasis;cd:0;major:0;
ph:1;time:163.8;tag:BOSS;spellid:1284458;lane:boss;label:Empowering Slam (2 s);cd:0;major:0;
ph:1;time:166.3;tag:BOSS;spellid:1284487;lane:boss;label:Bloodvenom Injection;cd:0;major:0;
ph:1;time:169.9;tag:BOSS;spellid:1284251;lane:boss;label:Venom Coagulation (2 s);cd:0;major:0;
ph:1;time:172.3;tag:BOSS;spellid:1284434;lane:boss;label:Toxic Droplets (2 s);cd:0;major:0;
ph:1;time:176;tag:BOSS;spellid:1288232;lane:boss;label:Unstable Miasma;cd:0;major:0;
ph:1;time:177.2;tag:BOSS;spellid:1284257;lane:boss;label:Contaminate;cd:0;major:0;
ph:1;time:185.7;tag:BOSS;spellid:1284458;lane:boss;label:Empowering Slam (2 s);cd:0;major:0;
ph:1;time:188.1;tag:BOSS;spellid:1284487;lane:boss;label:Bloodvenom Injection;cd:0;major:0;
ph:1;time:200.3;tag:BOSS;spellid:1284483;lane:boss;label:Blighted Blood (2 s);cd:0;major:0;
ph:1;time:205.1;tag:BOSS;spellid:1284434;lane:boss;label:Toxic Droplets (2 s);cd:0;major:0;
ph:1;time:207.5;tag:BOSS;spellid:1284458;lane:boss;label:Empowering Slam;cd:0;major:0;
ph:1;time:210;tag:BOSS;spellid:1284487;lane:boss;label:Bloodvenom Injection;cd:0;major:0;
ph:1;time:217.3;tag:BOSS;spellid:1288232;lane:boss;label:Unstable Miasma;cd:0;major:0;
ph:1;time:222.1;tag:BOSS;spellid:1284251;lane:boss;label:Venom Coagulation (2 s);cd:0;major:0;
ph:1;time:229.4;tag:BOSS;spellid:1284257;lane:boss;label:Contaminate;cd:0;major:0;
ph:1;time:229.4;tag:BOSS;spellid:1284458;lane:boss;label:Empowering Slam (2 s);cd:0;major:0;
ph:1;time:231.9;tag:BOSS;spellid:1284487;lane:boss;label:Bloodvenom Injection (2 s);cd:0;major:0;
ph:1;time:250.3;tag:BOSS;spellid:1284606;lane:boss;label:Vitriolic Stasis;cd:0;major:0;
]==]

-- Entombed Sentinels (Mythic), 92 boss casts
F[3445] = F[3445] or {}
F[3445][16] = [==[
EncounterID:3445;Difficulty:Mythic;Name:Entombed Sentinels;
duration:420;
curve:dmg;step:5;unit:k;data:132,251,386,1060,2004,2497,2452,1720,1298,1213,1216,1260,1277,1338,1891,2509,2352,1865,1688,1701,1901,1778,1395,1506,1851,2325,2519,2439,2057,1445,1279,1318,1482,1758,2276,2787,2508,2084,1872,1555,1656,1717,1909,1793,1952,2073,2216,2438,2583,2213,1279,1318,1482,1758,2276,2787,2508,2084,1872,1555,1656,1717,1909,1793,1952,2073,2216,2438,2583,2213,1279,1318,1482,1758,2276,2787,2508,2084,1872,1555,1656,1717,1909,1793;
lanedef:boss;name:Boss;kind:boss;
ph:1;time:6.3;tag:BOSS;spellid:1284458;lane:boss;label:Empowering Slam (tank);cd:0;major:0;
ph:1;time:7.5;tag:BOSS;spellid:1284487;lane:boss;label:Bloodvenom Injection;cd:0;major:0;
ph:1;time:12.4;tag:BOSS;spellid:1284251;lane:boss;label:Venom Coagulation (add);cd:0;major:0;
ph:1;time:15.3;tag:BOSS;spellid:1284434;lane:boss;label:Toxic Droplets;cd:0;major:0;
ph:1;time:18;tag:BOSS;spellid:1288232;lane:boss;label:Unstable Miasma;cd:0;major:0;
ph:1;time:18.2;tag:BOSS;spellid:1284257;lane:boss;label:Contaminate;cd:0;major:0;
ph:1;time:28.6;tag:BOSS;spellid:1284458;lane:boss;label:Empowering Slam (tank);cd:0;major:0;
ph:1;time:29.8;tag:BOSS;spellid:1284487;lane:boss;label:Bloodvenom Injection;cd:0;major:0;
ph:1;time:36.3;tag:BOSS;spellid:1296878;lane:boss;label:Shifting Protovenom;cd:0;major:0;
ph:1;time:42.9;tag:BOSS;spellid:1284483;lane:boss;label:Blighted Blood;cd:0;major:0;
ph:1;time:46.4;tag:BOSS;spellid:1284588;lane:boss;label:Vitriolic Stasis;cd:0;major:0;
ph:1;time:49.5;tag:BOSS;spellid:1297724;lane:boss;label:Concealing Shadows;cd:0;major:0;
ph:1;time:59.5;tag:BOSS;spellid:1284458;lane:boss;label:Empowering Slam (tank);cd:0;major:0;
ph:1;time:61.9;tag:BOSS;spellid:1284487;lane:boss;label:Bloodvenom Injection;cd:0;major:0;
ph:1;time:65.5;tag:BOSS;spellid:1284251;lane:boss;label:Venom Coagulation (add);cd:0;major:0;
ph:1;time:68.4;tag:BOSS;spellid:1284434;lane:boss;label:Toxic Droplets;cd:0;major:0;
ph:1;time:71.1;tag:BOSS;spellid:1288232;lane:boss;label:Unstable Miasma;cd:0;major:0;
ph:1;time:71.7;tag:BOSS;spellid:1284257;lane:boss;label:Contaminate;cd:0;major:0;
ph:1;time:81.3;tag:BOSS;spellid:1284458;lane:boss;label:Empowering Slam (tank);cd:0;major:0;
ph:1;time:86.2;tag:BOSS;spellid:1284487;lane:boss;label:Bloodvenom Injection;cd:0;major:0;
ph:1;time:93.3;tag:BOSS;spellid:1296878;lane:boss;label:Shifting Protovenom;cd:0;major:0;
ph:1;time:96.4;tag:BOSS;spellid:1284483;lane:boss;label:Blighted Blood;cd:0;major:0;
ph:1;time:101.2;tag:BOSS;spellid:1284434;lane:boss;label:Toxic Droplets;cd:0;major:0;
ph:1;time:104.4;tag:BOSS;spellid:1284458;lane:boss;label:Empowering Slam (tank);cd:0;major:0;
ph:1;time:108;tag:BOSS;spellid:1284487;lane:boss;label:Bloodvenom Injection;cd:0;major:0;
ph:1;time:112.4;tag:BOSS;spellid:1288232;lane:boss;label:Unstable Miasma;cd:0;major:0;
ph:1;time:117.8;tag:BOSS;spellid:1284251;lane:boss;label:Venom Coagulation (add);cd:0;major:0;
ph:1;time:123.6;tag:BOSS;spellid:1284257;lane:boss;label:Contaminate;cd:0;major:0;
ph:1;time:126.3;tag:BOSS;spellid:1284458;lane:boss;label:Empowering Slam (tank);cd:0;major:0;
ph:1;time:129.9;tag:BOSS;spellid:1284487;lane:boss;label:Bloodvenom Injection;cd:0;major:0;
ph:1;time:134.1;tag:BOSS;spellid:1284434;lane:boss;label:Toxic Droplets;cd:0;major:0;
ph:1;time:134.3;tag:BOSS;spellid:1296878;lane:boss;label:Shifting Protovenom;cd:0;major:0;
ph:1;time:144.4;tag:BOSS;spellid:1284588;lane:boss;label:Vitriolic Stasis;cd:0;major:0;
ph:1;time:147.4;tag:BOSS;spellid:1297724;lane:boss;label:Concealing Shadows;cd:0;major:0;
ph:1;time:161.5;tag:BOSS;spellid:1284458;lane:boss;label:Empowering Slam (tank);cd:0;major:0;
ph:1;time:162.8;tag:BOSS;spellid:1284487;lane:boss;label:Bloodvenom Injection;cd:0;major:0;
ph:1;time:166.4;tag:BOSS;spellid:1284251;lane:boss;label:Venom Coagulation (add);cd:0;major:0;
ph:1;time:169.3;tag:BOSS;spellid:1284434;lane:boss;label:Toxic Droplets;cd:0;major:0;
ph:1;time:172;tag:BOSS;spellid:1288232;lane:boss;label:Unstable Miasma;cd:0;major:0;
ph:1;time:172.2;tag:BOSS;spellid:1284257;lane:boss;label:Contaminate;cd:0;major:0;
ph:1;time:183.4;tag:BOSS;spellid:1284458;lane:boss;label:Empowering Slam (tank);cd:0;major:0;
ph:1;time:184.7;tag:BOSS;spellid:1284487;lane:boss;label:Bloodvenom Injection;cd:0;major:0;
ph:1;time:194.3;tag:BOSS;spellid:1296878;lane:boss;label:Shifting Protovenom;cd:0;major:0;
ph:1;time:197.3;tag:BOSS;spellid:1284483;lane:boss;label:Blighted Blood;cd:0;major:0;
ph:1;time:202.1;tag:BOSS;spellid:1284434;lane:boss;label:Toxic Droplets;cd:0;major:0;
ph:1;time:205.3;tag:BOSS;spellid:1284458;lane:boss;label:Empowering Slam (tank);cd:0;major:0;
ph:1;time:206.5;tag:BOSS;spellid:1284487;lane:boss;label:Bloodvenom Injection;cd:0;major:0;
ph:1;time:213.3;tag:BOSS;spellid:1288232;lane:boss;label:Unstable Miasma;cd:0;major:0;
ph:1;time:218.7;tag:BOSS;spellid:1284251;lane:boss;label:Venom Coagulation (add);cd:0;major:0;
ph:1;time:224.4;tag:BOSS;spellid:1284257;lane:boss;label:Contaminate;cd:0;major:0;
ph:1;time:227.2;tag:BOSS;spellid:1284458;lane:boss;label:Empowering Slam (tank);cd:0;major:0;
ph:1;time:228.4;tag:BOSS;spellid:1284487;lane:boss;label:Bloodvenom Injection;cd:0;major:0;
ph:1;time:234.9;tag:BOSS;spellid:1284434;lane:boss;label:Toxic Droplets;cd:0;major:0;
ph:1;time:235.3;tag:BOSS;spellid:1296878;lane:boss;label:Shifting Protovenom;cd:0;major:0;
ph:1;time:245.4;tag:BOSS;spellid:1284588;lane:boss;label:Vitriolic Stasis;cd:0;major:0;
ph:1;time:248.4;tag:BOSS;spellid:1297724;lane:boss;label:Concealing Shadows;cd:0;major:0;
ph:1;time:263.5;tag:BOSS;spellid:1284458;lane:boss;label:Empowering Slam (tank);cd:0;major:0;
ph:1;time:264.8;tag:BOSS;spellid:1284487;lane:boss;label:Bloodvenom Injection;cd:0;major:0;
ph:1;time:268.4;tag:BOSS;spellid:1284251;lane:boss;label:Venom Coagulation (add);cd:0;major:0;
ph:1;time:271.3;tag:BOSS;spellid:1284434;lane:boss;label:Toxic Droplets;cd:0;major:0;
ph:1;time:274;tag:BOSS;spellid:1288232;lane:boss;label:Unstable Miasma;cd:0;major:0;
ph:1;time:274.2;tag:BOSS;spellid:1284257;lane:boss;label:Contaminate;cd:0;major:0;
ph:1;time:285.4;tag:BOSS;spellid:1284458;lane:boss;label:Empowering Slam (tank);cd:0;major:0;
ph:1;time:286.7;tag:BOSS;spellid:1284487;lane:boss;label:Bloodvenom Injection;cd:0;major:0;
ph:1;time:296.3;tag:BOSS;spellid:1296878;lane:boss;label:Shifting Protovenom;cd:0;major:0;
ph:1;time:299.3;tag:BOSS;spellid:1284483;lane:boss;label:Blighted Blood;cd:0;major:0;
ph:1;time:304.1;tag:BOSS;spellid:1284434;lane:boss;label:Toxic Droplets;cd:0;major:0;
ph:1;time:307.3;tag:BOSS;spellid:1284458;lane:boss;label:Empowering Slam (tank);cd:0;major:0;
ph:1;time:308.5;tag:BOSS;spellid:1284487;lane:boss;label:Bloodvenom Injection;cd:0;major:0;
ph:1;time:315.3;tag:BOSS;spellid:1288232;lane:boss;label:Unstable Miasma;cd:0;major:0;
ph:1;time:320.7;tag:BOSS;spellid:1284251;lane:boss;label:Venom Coagulation (add);cd:0;major:0;
ph:1;time:326.4;tag:BOSS;spellid:1284257;lane:boss;label:Contaminate;cd:0;major:0;
ph:1;time:329.2;tag:BOSS;spellid:1284458;lane:boss;label:Empowering Slam (tank);cd:0;major:0;
ph:1;time:330.4;tag:BOSS;spellid:1284487;lane:boss;label:Bloodvenom Injection;cd:0;major:0;
ph:1;time:336.9;tag:BOSS;spellid:1284434;lane:boss;label:Toxic Droplets;cd:0;major:0;
ph:1;time:337.3;tag:BOSS;spellid:1296878;lane:boss;label:Shifting Protovenom;cd:0;major:0;
ph:1;time:347.4;tag:BOSS;spellid:1284588;lane:boss;label:Vitriolic Stasis;cd:0;major:0;
ph:1;time:350.4;tag:BOSS;spellid:1297724;lane:boss;label:Concealing Shadows;cd:0;major:0;
ph:1;time:365.5;tag:BOSS;spellid:1284458;lane:boss;label:Empowering Slam (tank);cd:0;major:0;
ph:1;time:366.8;tag:BOSS;spellid:1284487;lane:boss;label:Bloodvenom Injection;cd:0;major:0;
ph:1;time:370.4;tag:BOSS;spellid:1284251;lane:boss;label:Venom Coagulation (add);cd:0;major:0;
ph:1;time:373.3;tag:BOSS;spellid:1284434;lane:boss;label:Toxic Droplets;cd:0;major:0;
ph:1;time:376;tag:BOSS;spellid:1288232;lane:boss;label:Unstable Miasma;cd:0;major:0;
ph:1;time:376.2;tag:BOSS;spellid:1284257;lane:boss;label:Contaminate;cd:0;major:0;
ph:1;time:387.4;tag:BOSS;spellid:1284458;lane:boss;label:Empowering Slam (tank);cd:0;major:0;
ph:1;time:388.7;tag:BOSS;spellid:1284487;lane:boss;label:Bloodvenom Injection;cd:0;major:0;
ph:1;time:398.3;tag:BOSS;spellid:1296878;lane:boss;label:Shifting Protovenom;cd:0;major:0;
ph:1;time:401.3;tag:BOSS;spellid:1284483;lane:boss;label:Blighted Blood;cd:0;major:0;
ph:1;time:406.1;tag:BOSS;spellid:1284434;lane:boss;label:Toxic Droplets;cd:0;major:0;
ph:1;time:409.3;tag:BOSS;spellid:1284458;lane:boss;label:Empowering Slam (tank);cd:0;major:0;
ph:1;time:410.5;tag:BOSS;spellid:1284487;lane:boss;label:Bloodvenom Injection;cd:0;major:0;
ph:1;time:417.3;tag:BOSS;spellid:1288232;lane:boss;label:Unstable Miasma;cd:0;major:0;
]==]

-- Vashnik the Malignant (Heroic), 22 boss casts
F[3455] = F[3455] or {}
F[3455][15] = [==[
EncounterID:3455;Difficulty:Heroic;Name:Vashnik the Malignant;
duration:248;
curve:dmg;step:5;unit:k;data:87,154,477,955,1095,998,1267,1504,1333,1223,1042,1291,1229,695,563,599,455,660,1006,908,1133,1636,1375,1187,1399,1445,1318,1109,1247,1260,724,652,688,535,687,1111,1150,1275,1589,1386,1114,1071,1473,1488,1304,1467,1122,1027,1046,670;
lanedef:boss;name:Boss;kind:boss;
ph:1;time:8;tag:BOSS;spellid:1280935;lane:boss;label:Dripping Fangs (2 s);cd:0;major:0;
ph:1;time:20;tag:BOSS;spellid:1284663;lane:boss;label:Imbibe (4 s);cd:0;major:0;
ph:1;time:30;tag:BOSS;spellid:1282509;lane:boss;label:Malignant Catalyst;cd:0;major:0;
ph:1;time:36.9;tag:BOSS;spellid:1285979;lane:boss;label:Caustic Surge;cd:0;major:0;
ph:1;time:37;tag:BOSS;spellid:1280935;lane:boss;label:Dripping Fangs (2 s);cd:0;major:0;
ph:1;time:60.8;tag:BOSS;spellid:1285979;lane:boss;label:Caustic Surge;cd:0;major:0;
ph:1;time:64;tag:BOSS;spellid:1280935;lane:boss;label:Dripping Fangs (2 s);cd:0;major:0;
ph:1;time:69;tag:BOSS;spellid:1282509;lane:boss;label:Malignant Catalyst;cd:0;major:0;
ph:1;time:92;tag:BOSS;spellid:1280935;lane:boss;label:Dripping Fangs (2 s);cd:0;major:0;
ph:1;time:104;tag:BOSS;spellid:1284663;lane:boss;label:Imbibe (4 s);cd:0;major:0;
ph:1;time:114.1;tag:BOSS;spellid:1282509;lane:boss;label:Malignant Catalyst;cd:0;major:0;
ph:1;time:121.1;tag:BOSS;spellid:1280935;lane:boss;label:Dripping Fangs (2 s);cd:0;major:0;
ph:1;time:122.3;tag:BOSS;spellid:1285979;lane:boss;label:Caustic Surge;cd:0;major:0;
ph:1;time:145.4;tag:BOSS;spellid:1285979;lane:boss;label:Caustic Surge;cd:0;major:0;
ph:1;time:148.1;tag:BOSS;spellid:1280935;lane:boss;label:Dripping Fangs (2 s);cd:0;major:0;
ph:1;time:153;tag:BOSS;spellid:1282509;lane:boss;label:Malignant Catalyst;cd:0;major:0;
ph:1;time:176.1;tag:BOSS;spellid:1280935;lane:boss;label:Dripping Fangs (2 s);cd:0;major:0;
ph:1;time:188.1;tag:BOSS;spellid:1284663;lane:boss;label:Imbibe (4 s);cd:0;major:0;
ph:1;time:198.1;tag:BOSS;spellid:1282509;lane:boss;label:Malignant Catalyst;cd:0;major:0;
ph:1;time:205.1;tag:BOSS;spellid:1280935;lane:boss;label:Dripping Fangs (2 s);cd:0;major:0;
ph:1;time:232.1;tag:BOSS;spellid:1280935;lane:boss;label:Dripping Fangs (2 s);cd:0;major:0;
ph:1;time:237.1;tag:BOSS;spellid:1282509;lane:boss;label:Malignant Catalyst;cd:0;major:0;
]==]

-- Nek'zali the Soulcoiler (Heroic), 11 boss casts
F[3470] = F[3470] or {}
F[3470][15] = [==[
EncounterID:3470;Difficulty:Heroic;Name:Nek'zali the Soulcoiler;
duration:240;
curve:dmg;step:5;unit:k;data:569,1092,1082,1011,965,892,1111,1385,1112,806,444,216,354,438,539,585,552,548,556,316,372,663,611,449,318,354,329,298,633,731,484,421,401,352,407,706,729,475,392,665,1015,1122,1306,1294,1026,1236,1080,597,439;
lanedef:boss;name:Boss;kind:boss;
ph:1;time:0.1;tag:BOSS;spellid:1285681;lane:boss;label:Soulcoil Ignition (3 s);cd:0;major:0;
ph:1;time:28;tag:BOSS;spellid:1284103;lane:boss;label:Possession Barrage (6 s);cd:0;major:0;
ph:1;time:68.3;tag:BOSS;spellid:1295124;lane:boss;label:Ritual of Awakening (2 s);cd:0;major:0;
ph:1;time:80.3;tag:BOSS;spellid:1289902;lane:boss;label:Soul Transfer;cd:0;major:0;
ph:1;time:98.3;tag:BOSS;spellid:1289855;lane:boss;label:Hungering Pyre;cd:0;major:0;
ph:1;time:116.9;tag:BOSS;spellid:1289902;lane:boss;label:Soul Transfer (15 s);cd:0;major:0;
ph:1;time:135;tag:BOSS;spellid:1289855;lane:boss;label:Hungering Pyre;cd:0;major:0;
ph:1;time:160;tag:BOSS;spellid:1299673;lane:boss;label:Invoke (5 s);cd:0;major:0;
ph:1;time:192;tag:BOSS;spellid:1284103;lane:boss;label:Possession Barrage (6 s);cd:0;major:0;
ph:1;time:208;tag:BOSS;spellid:1299673;lane:boss;label:Invoke (5 s);cd:0;major:0;
ph:1;time:219.9;tag:BOSS;spellid:1284103;lane:boss;label:Possession Barrage (6 s);cd:0;major:0;
]==]

-- Nek'zali the Soulcoiler (Mythic), 29 boss casts
F[3470] = F[3470] or {}
F[3470][16] = [==[
EncounterID:3470;Difficulty:Mythic;Name:Nek'zali the Soulcoiler;
duration:447;
curve:dmg;step:5;unit:k;data:827,1072,1397,1248,1295,1558,1551,1530,1589,1248,1210,1191,1208,1438,1631,1728,1755,1740,1527,1493,1520,1539,1582,1584,1478,1395,1162,838,712,657,710,700,635,771,774,790,823,849,943,1070,1070,921,877,764,794,1144,1148,1200,1362,1338,1382,1456,1296,1215,1152,871,754,706,803,1050,1253,1443,1666,1631,1644,1794,1574,1552,1442,1388,1745,2038,2031,2101,1747,1552,1592,1608,1873,1897,1824,1887,1876,1875,1755,1592,1780,1952,1678,1380;
lanedef:boss;name:Boss;kind:boss;
ph:1;time:3;tag:BOSS;spellid:1285681;lane:boss;label:Soulcoil Ignition (Rite ramps);cd:0;major:0;
ph:1;time:28;tag:BOSS;spellid:1284103;lane:boss;label:Possession Barrage (6 s);cd:0;major:0;
ph:1;time:45;tag:BOSS;spellid:1308227;lane:boss;label:Immortal Coil;cd:0;major:0;
ph:1;time:64;tag:BOSS;spellid:1284103;lane:boss;label:Possession Barrage (6 s);cd:0;major:0;
ph:1;time:77;tag:BOSS;spellid:1285681;lane:boss;label:Soulcoil Ignition (Rite ramps);cd:0;major:0;
ph:1;time:99;tag:BOSS;spellid:1284103;lane:boss;label:Possession Barrage (6 s);cd:0;major:0;
ph:1;time:117;tag:BOSS;spellid:1308227;lane:boss;label:Immortal Coil;cd:0;major:0;
ph:1;time:135.5;tag:BOSS;spellid:1295124;lane:boss;label:Ritual of Awakening (P2);cd:0;major:0;
ph:1;time:146;tag:BOSS;spellid:1292248;lane:boss;label:Soul Transfer;cd:0;major:0;
ph:1;time:161;tag:BOSS;spellid:1293211;lane:boss;label:Echo of Jawae: Soul Transfer;cd:0;major:0;
ph:1;time:164;tag:BOSS;spellid:1289855;lane:boss;label:Hungering Pyre (7.5 s);cd:0;major:0;
ph:1;time:173;tag:BOSS;spellid:1289875;lane:boss;label:Cremation (mass souls);cd:0;major:0;
ph:1;time:183;tag:BOSS;spellid:1308227;lane:boss;label:Immortal Coil;cd:0;major:0;
ph:1;time:191.4;tag:BOSS;spellid:1289855;lane:boss;label:Hungering Pyre (7.5 s);cd:0;major:0;
ph:1;time:221;tag:BOSS;spellid:1293211;lane:boss;label:Echo of Jawae: Soul Transfer;cd:0;major:0;
ph:1;time:227;tag:BOSS;spellid:1289875;lane:boss;label:Cremation (mass souls);cd:0;major:0;
ph:1;time:242;tag:BOSS;spellid:1308227;lane:boss;label:Immortal Coil;cd:0;major:0;
ph:1;time:264.3;tag:BOSS;spellid:1289855;lane:boss;label:Hungering Pyre (7.5 s);cd:0;major:0;
ph:1;time:292.7;tag:BOSS;spellid:1299673;lane:boss;label:Invoke (5 s) - P3;cd:0;major:0;
ph:1;time:309;tag:BOSS;spellid:1308227;lane:boss;label:Immortal Coil;cd:0;major:0;
ph:1;time:324.7;tag:BOSS;spellid:1284103;lane:boss;label:Possession Barrage (6 s);cd:0;major:0;
ph:1;time:340.7;tag:BOSS;spellid:1299673;lane:boss;label:Invoke (5 s) - P3;cd:0;major:0;
ph:1;time:352.7;tag:BOSS;spellid:1284103;lane:boss;label:Possession Barrage (6 s);cd:0;major:0;
ph:1;time:354;tag:BOSS;spellid:1308227;lane:boss;label:Immortal Coil;cd:0;major:0;
ph:1;time:372.7;tag:BOSS;spellid:1299673;lane:boss;label:Invoke (5 s) - P3;cd:0;major:0;
ph:1;time:393;tag:BOSS;spellid:1308227;lane:boss;label:Immortal Coil;cd:0;major:0;
ph:1;time:404.7;tag:BOSS;spellid:1284103;lane:boss;label:Possession Barrage (6 s);cd:0;major:0;
ph:1;time:420.7;tag:BOSS;spellid:1299673;lane:boss;label:Invoke (5 s) - P3;cd:0;major:0;
ph:1;time:432.7;tag:BOSS;spellid:1284103;lane:boss;label:Possession Barrage (6 s);cd:0;major:0;
]==]

-- Ula'tek (Heroic), 52 boss casts
F[3492] = F[3492] or {}
F[3492][15] = [==[
EncounterID:3492;Difficulty:Heroic;Name:Ula'tek;
duration:590;
curve:dmg;step:5;unit:k;data:345,643,819,1021,1374,1373,1933,1870,1601,1507,891,755,681,654,671,871,1490,1936,2145,2074,1598,1290,1445,1812,1801,1996,1832,1587,1757,1657,1465,1361,1236,1151,1232,1218,1175,1486,1664,1948,2196,1909,1810,1514,1293,1251,1137,1105,1046,1090,1106,1105,1073,1007,963,1214,1443,1688,1972,1910,1685,1394,1179,1184,1464,1885,2236,2287,1997,1467,1095,823,826,981,1060,1102,1153,1402,1434,1442,1654,1879,2084,2344,2400,1912,1566,1267,968,1072,1215,1609,2202,2755,2937,2306,1879,2084,2344,2400,1912,1566,1267,968,1072,1215,1609,2202,2755,2937,2306,1879,2084,2344,2400,1912,1566,1267;
lanedef:boss;name:Boss (at hit);kind:boss;
ph:1;time:15;tag:BOSS;spellid:1298367;lane:boss;label:Mother's Wrath - tank knockback;cd:0;major:0;
ph:1;time:20;tag:BOSS;spellid:1299010;lane:boss;label:Gore Rattle > Spectral Coils spawn;cd:0;major:0;
ph:1;time:27.5;tag:BOSS;spellid:1299010;lane:boss;label:Spectral Coils soak;cd:0;major:0;
ph:1;time:30.3;tag:BOSS;spellid:1299010;lane:boss;label:Spectral Coils soak;cd:0;major:0;
ph:1;time:39;tag:BOSS;spellid:1296301;lane:boss;label:Mephitic Thrash (sweep);cd:0;major:0;
ph:1;time:48;tag:BOSS;spellid:1319282;lane:boss;label:Caustic Waves;cd:0;major:0;
ph:1;time:64.4;tag:BOSS;spellid:1292521;lane:boss;label:Submerge;cd:0;major:0;
ph:1;time:76;tag:BOSS;spellid:1304012;lane:boss;label:Call of the Serpent (eggs);cd:0;major:0;
ph:1;time:82;tag:BOSS;spellid:1298367;lane:boss;label:Mother's Wrath - tank knockback;cd:0;major:0;
ph:1;time:91;tag:BOSS;spellid:1296301;lane:boss;label:Mephitic Thrash (sweep);cd:0;major:0;
ph:1;time:100;tag:BOSS;spellid:1319282;lane:boss;label:Caustic Waves;cd:0;major:0;
ph:1;time:115;tag:BOSS;spellid:1299010;lane:boss;label:Gore Rattle > Spectral Coils spawn;cd:0;major:0;
ph:1;time:119;tag:BOSS;spellid:1298367;lane:boss;label:Mother's Wrath - tank knockback;cd:0;major:0;
ph:1;time:122.3;tag:BOSS;spellid:1299010;lane:boss;label:Spectral Coils soak;cd:0;major:0;
ph:1;time:125.5;tag:BOSS;spellid:1299010;lane:boss;label:Spectral Coils soak;cd:0;major:0;
ph:1;time:135.5;tag:BOSS;spellid:1286860;lane:boss;label:Rage of the Shackled > Stage 2;cd:0;major:0;
ph:1;time:163.6;tag:BOSS;spellid:1295995;lane:boss;label:Toxin Cloud;cd:0;major:0;
ph:1;time:172.3;tag:BOSS;spellid:1301213;lane:boss;label:Shadow Molt (Warden teleport) ~;cd:0;major:0;
ph:1;time:175.8;tag:BOSS;spellid:1302950;lane:boss;label:Writhing Gestation ~;cd:0;major:0;
ph:1;time:189;tag:BOSS;spellid:1301117;lane:boss;label:Grasping Fangs (tethers) ~;cd:0;major:0;
ph:1;time:200.5;tag:BOSS;spellid:1302950;lane:boss;label:Writhing Gestation ~;cd:0;major:0;
ph:1;time:227;tag:BOSS;spellid:1303410;lane:boss;label:Defect: Weakened ~;cd:0;major:0;
ph:1;time:245.6;tag:BOSS;spellid:1305709;lane:boss;label:Desperate Thrash ~;cd:0;major:0;
ph:1;time:264.2;tag:BOSS;spellid:1305709;lane:boss;label:Desperate Thrash ~;cd:0;major:0;
ph:1;time:284.5;tag:BOSS;spellid:1286860;lane:boss;label:Rage of the Shackled;cd:0;major:0;
ph:1;time:313;tag:BOSS;spellid:1304012;lane:boss;label:Call of the Serpent (eggs);cd:0;major:0;
ph:1;time:326.4;tag:BOSS;spellid:1299010;lane:boss;label:Spectral Coils soak (intermission);cd:0;major:0;
ph:1;time:329.7;tag:BOSS;spellid:1299010;lane:boss;label:Spectral Coils soak (intermission);cd:0;major:0;
ph:1;time:334.5;tag:BOSS;spellid:1299010;lane:boss;label:Spectral Coils soak (intermission);cd:0;major:0;
ph:1;time:336.9;tag:BOSS;spellid:1299010;lane:boss;label:Spectral Coils soak (intermission);cd:0;major:0;
ph:1;time:341.4;tag:BOSS;spellid:1299010;lane:boss;label:Spectral Coils soak (intermission);cd:0;major:0;
ph:1;time:344.6;tag:BOSS;spellid:1299010;lane:boss;label:Spectral Coils soak (intermission);cd:0;major:0;
ph:1;time:371.2;tag:BOSS;spellid:1304012;lane:boss;label:Call of the Serpent (eggs);cd:0;major:0;
ph:1;time:377.2;tag:BOSS;spellid:1298367;lane:boss;label:Mother's Wrath - tank knockback;cd:0;major:0;
ph:1;time:392.2;tag:BOSS;spellid:1295905;lane:boss;label:Serpent's Bite (soaks);cd:0;major:0;
ph:1;time:401.2;tag:BOSS;spellid:1304012;lane:boss;label:Call of the Serpent (eggs);cd:0;major:0;
ph:1;time:416.7;tag:BOSS;spellid:1319282;lane:boss;label:Caustic Waves;cd:0;major:0;
ph:1;time:430.2;tag:BOSS;spellid:1315341;lane:boss;label:Circling Prey (platform break);cd:0;major:0;
ph:1;time:432.6;tag:BOSS;spellid:1292521;lane:boss;label:Submerge;cd:0;major:0;
ph:1;time:446.2;tag:BOSS;spellid:1304012;lane:boss;label:Call of the Serpent (eggs);cd:0;major:0;
ph:1;time:452.2;tag:BOSS;spellid:1298367;lane:boss;label:Mother's Wrath - tank knockback;cd:0;major:0;
ph:1;time:467.2;tag:BOSS;spellid:1295905;lane:boss;label:Serpent's Bite (soaks);cd:0;major:0;
ph:1;time:476.2;tag:BOSS;spellid:1304012;lane:boss;label:Call of the Serpent (eggs);cd:0;major:0;
ph:1;time:491.7;tag:BOSS;spellid:1319282;lane:boss;label:Caustic Waves;cd:0;major:0;
ph:1;time:505.2;tag:BOSS;spellid:1315341;lane:boss;label:Circling Prey (platform break);cd:0;major:0;
ph:1;time:507.6;tag:BOSS;spellid:1292521;lane:boss;label:Submerge;cd:0;major:0;
ph:1;time:521.2;tag:BOSS;spellid:1304012;lane:boss;label:Call of the Serpent (eggs);cd:0;major:0;
ph:1;time:527.2;tag:BOSS;spellid:1298367;lane:boss;label:Mother's Wrath - tank knockback;cd:0;major:0;
ph:1;time:542.2;tag:BOSS;spellid:1295905;lane:boss;label:Serpent's Bite (soaks);cd:0;major:0;
ph:1;time:551.2;tag:BOSS;spellid:1304012;lane:boss;label:Call of the Serpent (eggs);cd:0;major:0;
ph:1;time:566.7;tag:BOSS;spellid:1319282;lane:boss;label:Caustic Waves;cd:0;major:0;
ph:1;time:573.7;tag:BOSS;spellid:1286860;lane:boss;label:Rage of the Shackled;cd:0;major:0;
]==]

-- The Lost Explorers (Heroic), 29 boss casts
F[3497] = F[3497] or {}
F[3497][15] = [==[
EncounterID:3497;Difficulty:Heroic;Name:The Lost Explorers;
duration:227;
curve:dmg;step:5;unit:k;data:350,510,631,876,659,666,914,954,1006,1031,696,653,907,1443,1365,926,616,517,597,614,820,1128,1132,1017,780,615,510,674,901,1072,805,726,1002,919,787,1262,1066,483,566,813,1270,1054,708,768,648,357;
lanedef:boss;name:Boss;kind:boss;
ph:1;time:0;tag:BOSS;spellid:1297075;lane:boss;label:Final Ascension;cd:0;major:0;
ph:1;time:10;tag:BOSS;spellid:1296025;lane:boss;label:Blink Nova;cd:0;major:0;
ph:1;time:18;tag:BOSS;spellid:1296062;lane:boss;label:Shell Spin (4 s);cd:0;major:0;
ph:1;time:30;tag:BOSS;spellid:1310616;lane:boss;label:Shredding Shards;cd:0;major:0;
ph:1;time:34;tag:BOSS;spellid:1296062;lane:boss;label:Shell Spin (4 s);cd:0;major:0;
ph:1;time:41;tag:BOSS;spellid:1296025;lane:boss;label:Blink Nova;cd:0;major:0;
ph:1;time:49;tag:BOSS;spellid:1296062;lane:boss;label:Shell Spin (4 s);cd:0;major:0;
ph:1;time:60.8;tag:BOSS;spellid:1297075;lane:boss;label:Final Ascension (5 s);cd:0;major:0;
ph:1;time:69.3;tag:BOSS;spellid:1296975;lane:boss;label:Mor'zahi's Command;cd:0;major:0;
ph:1;time:70;tag:BOSS;spellid:1296025;lane:boss;label:Blink Nova;cd:0;major:0;
ph:1;time:74.8;tag:BOSS;spellid:1292105;lane:boss;label:Mushroom Toss (7 s);cd:0;major:0;
ph:1;time:78.8;tag:BOSS;spellid:1296062;lane:boss;label:Shell Spin (4 s);cd:0;major:0;
ph:1;time:84.8;tag:BOSS;spellid:1296249;lane:boss;label:Explosive Surprise;cd:0;major:0;
ph:1;time:101.8;tag:BOSS;spellid:1310616;lane:boss;label:Shredding Shards;cd:0;major:0;
ph:1;time:106.8;tag:BOSS;spellid:1292105;lane:boss;label:Mushroom Toss (7 s);cd:0;major:0;
ph:1;time:110.8;tag:BOSS;spellid:1296062;lane:boss;label:Shell Spin (4 s);cd:0;major:0;
ph:1;time:116.8;tag:BOSS;spellid:1296249;lane:boss;label:Explosive Surprise;cd:0;major:0;
ph:1;time:129.3;tag:BOSS;spellid:1301667;lane:boss;label:Dark Whispers;cd:0;major:0;
ph:1;time:130.2;tag:BOSS;spellid:1297075;lane:boss;label:Final Ascension;cd:0;major:0;
ph:1;time:141.8;tag:BOSS;spellid:1296025;lane:boss;label:Blink Nova;cd:0;major:0;
ph:1;time:149.8;tag:BOSS;spellid:1296062;lane:boss;label:Shell Spin (4 s);cd:0;major:0;
ph:1;time:161.8;tag:BOSS;spellid:1310616;lane:boss;label:Shredding Shards;cd:0;major:0;
ph:1;time:165.8;tag:BOSS;spellid:1296062;lane:boss;label:Shell Spin (4 s);cd:0;major:0;
ph:1;time:172.8;tag:BOSS;spellid:1296025;lane:boss;label:Blink Nova;cd:0;major:0;
ph:1;time:180.8;tag:BOSS;spellid:1296062;lane:boss;label:Shell Spin (4 s);cd:0;major:0;
ph:1;time:186.5;tag:BOSS;spellid:1296975;lane:boss;label:Mor'zahi's Command;cd:0;major:0;
ph:1;time:190.7;tag:BOSS;spellid:1296095;lane:boss;label:Mighty Thud (10 s);cd:0;major:0;
ph:1;time:204.7;tag:BOSS;spellid:1310028;lane:boss;label:Relic Rupture;cd:0;major:0;
ph:1;time:217.7;tag:BOSS;spellid:1310616;lane:boss;label:Shredding Shards;cd:0;major:0;
]==]

-- Kith'ix (Heroic), 28 boss casts
F[3513] = F[3513] or {}
F[3513][15] = [==[
EncounterID:3513;Difficulty:Heroic;Name:Kith'ix;
duration:440;
curve:dmg;step:5;unit:k;data:451,1564,3710,3970,3418,807,1100,1459,1261,627,301,662,1073,1846,2204,1865,2029,1006,1060,945,550,520,477,1575,3532,2886,2356,1457,732,1272,1867,1126,537,752,1381,1285,2439,2493,1261,1042,940,610,639,832,1011,1074,1457,1427,1520,2224,1663,1272,1867,1126,537,752,1381,1285,2439,2493,1261,1042,940,610,639,832,1011,1074,1457,1427,1520,2224,1663,1272,1867,1126,537,752,1381,1285,2439,2493,1261,1042,940,610,639,832;
lanedef:boss;name:Boss (at hit);kind:boss;
ph:1;time:10;tag:BOSS;spellid:1301511;lane:boss;label:Voidswarm (raid, ~15 s);cd:0;major:0;
ph:1;time:37;tag:BOSS;spellid:1304424;lane:boss;label:Extinguish;cd:0;major:0;
ph:1;time:37.5;tag:BOSS;spellid:1304045;lane:boss;label:Unspeakable Horrors (fear);cd:0;major:0;
ph:1;time:58;tag:BOSS;spellid:1302951;lane:boss;label:Suffocating Darkness + Abyssal Grasp;cd:0;major:0;
ph:1;time:70;tag:BOSS;spellid:1304045;lane:boss;label:Unspeakable Horrors (fear);cd:0;major:0;
ph:1;time:87;tag:BOSS;spellid:1303406;lane:boss;label:Abyssal Grasp;cd:0;major:0;
ph:1;time:94;tag:BOSS;spellid:1304424;lane:boss;label:Extinguish;cd:0;major:0;
ph:1;time:119;tag:BOSS;spellid:1301511;lane:boss;label:Voidswarm (raid, ~15 s);cd:0;major:0;
ph:1;time:146;tag:BOSS;spellid:1304424;lane:boss;label:Extinguish;cd:0;major:0;
ph:1;time:146.5;tag:BOSS;spellid:1304045;lane:boss;label:Unspeakable Horrors (fear);cd:0;major:0;
ph:1;time:167;tag:BOSS;spellid:1302951;lane:boss;label:Suffocating Darkness + Abyssal Grasp;cd:0;major:0;
ph:1;time:179;tag:BOSS;spellid:1304045;lane:boss;label:Unspeakable Horrors (fear);cd:0;major:0;
ph:1;time:196;tag:BOSS;spellid:1303406;lane:boss;label:Abyssal Grasp;cd:0;major:0;
ph:1;time:203;tag:BOSS;spellid:1304424;lane:boss;label:Extinguish;cd:0;major:0;
ph:1;time:228;tag:BOSS;spellid:1301511;lane:boss;label:Voidswarm (raid, ~15 s);cd:0;major:0;
ph:1;time:255;tag:BOSS;spellid:1304424;lane:boss;label:Extinguish;cd:0;major:0;
ph:1;time:255.5;tag:BOSS;spellid:1304045;lane:boss;label:Unspeakable Horrors (fear);cd:0;major:0;
ph:1;time:276;tag:BOSS;spellid:1302951;lane:boss;label:Suffocating Darkness + Abyssal Grasp;cd:0;major:0;
ph:1;time:288;tag:BOSS;spellid:1304045;lane:boss;label:Unspeakable Horrors (fear);cd:0;major:0;
ph:1;time:305;tag:BOSS;spellid:1303406;lane:boss;label:Abyssal Grasp;cd:0;major:0;
ph:1;time:312;tag:BOSS;spellid:1304424;lane:boss;label:Extinguish;cd:0;major:0;
ph:1;time:337;tag:BOSS;spellid:1301511;lane:boss;label:Voidswarm (raid, ~15 s);cd:0;major:0;
ph:1;time:364;tag:BOSS;spellid:1304424;lane:boss;label:Extinguish;cd:0;major:0;
ph:1;time:364.5;tag:BOSS;spellid:1304045;lane:boss;label:Unspeakable Horrors (fear);cd:0;major:0;
ph:1;time:385;tag:BOSS;spellid:1302951;lane:boss;label:Suffocating Darkness + Abyssal Grasp;cd:0;major:0;
ph:1;time:397;tag:BOSS;spellid:1304045;lane:boss;label:Unspeakable Horrors (fear);cd:0;major:0;
ph:1;time:414;tag:BOSS;spellid:1303406;lane:boss;label:Abyssal Grasp;cd:0;major:0;
ph:1;time:421;tag:BOSS;spellid:1304424;lane:boss;label:Extinguish;cd:0;major:0;
]==]

-- Kith'ix (Mythic), 24 boss casts
F[3513] = F[3513] or {}
F[3513][16] = [==[
EncounterID:3513;Difficulty:Mythic;Name:Kith'ix;
duration:440;
curve:dmg;step:5;unit:k;data:721,1863,3399,2870,3412,3024,2319,1798,1660,1214,741,749,1704,1880,2034,1660,2771,3212,3023,1436,726,338,915,2198,3689,4108,3200,4232,4061,3110,1318,1314,760,1259,1572,2292,2845,2984,2355,3008,2736,1857,650,394,1313,1256,1734,1332,1346,803,832,1253,1736,1220,2800,2755,3596,2848,4255,4569,3871,2441,1351,600,650,394,1313,1256,1734,1332,1346,803,832,1253,1736,1220,2800,2755,3596,2848,4255,4569,3871,2441,1351,600,650,394;
lanedef:boss;name:Boss (at hit);kind:boss;
ph:1;time:10;tag:BOSS;spellid:1301511;lane:boss;label:Voidswarm (raid, ~15 s);cd:0;major:0;
ph:1;time:36;tag:BOSS;spellid:1304424;lane:boss;label:Extinguish;cd:0;major:0;
ph:1;time:37;tag:BOSS;spellid:1304045;lane:boss;label:Unspeakable Horrors (fear);cd:0;major:0;
ph:1;time:57;tag:BOSS;spellid:1302951;lane:boss;label:Suffocating Darkness + Abyssal Grasp;cd:0;major:0;
ph:1;time:78;tag:BOSS;spellid:1304424;lane:boss;label:Extinguish;cd:0;major:0;
ph:1;time:84;tag:BOSS;spellid:1304045;lane:boss;label:Unspeakable Horrors + Abyssal Grasp;cd:0;major:0;
ph:1;time:119;tag:BOSS;spellid:1301511;lane:boss;label:Voidswarm (raid, ~15 s);cd:0;major:0;
ph:1;time:145;tag:BOSS;spellid:1304424;lane:boss;label:Extinguish;cd:0;major:0;
ph:1;time:146;tag:BOSS;spellid:1304045;lane:boss;label:Unspeakable Horrors (fear);cd:0;major:0;
ph:1;time:166;tag:BOSS;spellid:1302951;lane:boss;label:Suffocating Darkness + Abyssal Grasp;cd:0;major:0;
ph:1;time:187;tag:BOSS;spellid:1304424;lane:boss;label:Extinguish;cd:0;major:0;
ph:1;time:193;tag:BOSS;spellid:1304045;lane:boss;label:Unspeakable Horrors + Abyssal Grasp;cd:0;major:0;
ph:1;time:228;tag:BOSS;spellid:1301511;lane:boss;label:Voidswarm (raid, ~15 s);cd:0;major:0;
ph:1;time:254;tag:BOSS;spellid:1304424;lane:boss;label:Extinguish;cd:0;major:0;
ph:1;time:255;tag:BOSS;spellid:1304045;lane:boss;label:Unspeakable Horrors (fear);cd:0;major:0;
ph:1;time:275;tag:BOSS;spellid:1302951;lane:boss;label:Suffocating Darkness + Abyssal Grasp;cd:0;major:0;
ph:1;time:296;tag:BOSS;spellid:1304424;lane:boss;label:Extinguish;cd:0;major:0;
ph:1;time:302;tag:BOSS;spellid:1304045;lane:boss;label:Unspeakable Horrors + Abyssal Grasp;cd:0;major:0;
ph:1;time:337;tag:BOSS;spellid:1301511;lane:boss;label:Voidswarm (raid, ~15 s);cd:0;major:0;
ph:1;time:363;tag:BOSS;spellid:1304424;lane:boss;label:Extinguish;cd:0;major:0;
ph:1;time:364;tag:BOSS;spellid:1304045;lane:boss;label:Unspeakable Horrors (fear);cd:0;major:0;
ph:1;time:384;tag:BOSS;spellid:1302951;lane:boss;label:Suffocating Darkness + Abyssal Grasp;cd:0;major:0;
ph:1;time:405;tag:BOSS;spellid:1304424;lane:boss;label:Extinguish;cd:0;major:0;
ph:1;time:411;tag:BOSS;spellid:1304045;lane:boss;label:Unspeakable Horrors + Abyssal Grasp;cd:0;major:0;
]==]

-- Mythic plans for the rest of The Venomous Abyss, from public Warcraft Logs kills (no guild kill yet)
-- Vashnik the Malignant (Mythic), 34 boss casts – Warcraft Logs report wXbVyCjGncMg8xT1 fight 10 (328 s, a median-length top healing-ranked kill)
F[3455] = F[3455] or {}
F[3455][16] = [==[
EncounterID:3455;Difficulty:Mythic;Name:Vashnik the Malignant;
duration:328;
curve:dmg;step:5;unit:k;data:54,191,490,741,1014,1252,1655,1994,2179,2111,2203,1622,1162,567,681,712,541,658,1075,1480,1725,1868,1825,1783,2070,2437,2455,2517,2005,1320,953,858,864,760,865,1182,1228,1797,1918,1847,1636,1693,1708,1937,2159,1872,1479,1095,1082,816,657,893,1251,1358,2044,2514,3048,2693,2645,2491,2307,1614,1073,635,539,408;
lanedef:boss;name:Boss;kind:boss;
ph:1;time:10;tag:BOSS;spellid:1280935;lane:boss;label:Dripping Fangs (2 s);cd:0;major:0;
ph:1;time:24;tag:BOSS;spellid:1284663;lane:boss;label:Imbibe (4 s);cd:0;major:0;
ph:1;time:30;tag:BOSS;spellid:1282509;lane:boss;label:Malignant Catalyst;cd:0;major:0;
ph:1;time:32.3;tag:BOSS;spellid:1285979;lane:boss;label:Caustic Surge;cd:0;major:0;
ph:1;time:38.9;tag:BOSS;spellid:1285979;lane:boss;label:Caustic Surge;cd:0;major:0;
ph:1;time:39;tag:BOSS;spellid:1280935;lane:boss;label:Dripping Fangs (2 s);cd:0;major:0;
ph:1;time:56;tag:BOSS;spellid:1285979;lane:boss;label:Caustic Surge;cd:0;major:0;
ph:1;time:66;tag:BOSS;spellid:1280935;lane:boss;label:Dripping Fangs (2 s);cd:0;major:0;
ph:1;time:69;tag:BOSS;spellid:1282509;lane:boss;label:Malignant Catalyst;cd:0;major:0;
ph:1;time:94;tag:BOSS;spellid:1280935;lane:boss;label:Dripping Fangs (2 s);cd:0;major:0;
ph:1;time:108;tag:BOSS;spellid:1284663;lane:boss;label:Imbibe (4 s);cd:0;major:0;
ph:1;time:114;tag:BOSS;spellid:1282509;lane:boss;label:Malignant Catalyst;cd:0;major:0;
ph:1;time:122.7;tag:BOSS;spellid:1285979;lane:boss;label:Caustic Surge;cd:0;major:0;
ph:1;time:123;tag:BOSS;spellid:1280935;lane:boss;label:Dripping Fangs (2 s);cd:0;major:0;
ph:1;time:129.1;tag:BOSS;spellid:1285979;lane:boss;label:Caustic Surge;cd:0;major:0;
ph:1;time:140.6;tag:BOSS;spellid:1285979;lane:boss;label:Caustic Surge;cd:0;major:0;
ph:1;time:150;tag:BOSS;spellid:1280935;lane:boss;label:Dripping Fangs (2 s);cd:0;major:0;
ph:1;time:153;tag:BOSS;spellid:1282509;lane:boss;label:Malignant Catalyst;cd:0;major:0;
ph:1;time:178;tag:BOSS;spellid:1280935;lane:boss;label:Dripping Fangs (2 s);cd:0;major:0;
ph:1;time:192.1;tag:BOSS;spellid:1284663;lane:boss;label:Imbibe (4 s);cd:0;major:0;
ph:1;time:198.1;tag:BOSS;spellid:1282509;lane:boss;label:Malignant Catalyst;cd:0;major:0;
ph:1;time:207;tag:BOSS;spellid:1280935;lane:boss;label:Dripping Fangs (2 s);cd:0;major:0;
ph:1;time:207.3;tag:BOSS;spellid:1285979;lane:boss;label:Caustic Surge;cd:0;major:0;
ph:1;time:223.9;tag:BOSS;spellid:1285979;lane:boss;label:Caustic Surge;cd:0;major:0;
ph:1;time:234;tag:BOSS;spellid:1280935;lane:boss;label:Dripping Fangs (2 s);cd:0;major:0;
ph:1;time:236;tag:BOSS;spellid:1285979;lane:boss;label:Caustic Surge;cd:0;major:0;
ph:1;time:237;tag:BOSS;spellid:1282509;lane:boss;label:Malignant Catalyst;cd:0;major:0;
ph:1;time:262.1;tag:BOSS;spellid:1280935;lane:boss;label:Dripping Fangs (2 s);cd:0;major:0;
ph:1;time:276.1;tag:BOSS;spellid:1284663;lane:boss;label:Imbibe (4 s);cd:0;major:0;
ph:1;time:282.1;tag:BOSS;spellid:1282509;lane:boss;label:Malignant Catalyst;cd:0;major:0;
ph:1;time:291.1;tag:BOSS;spellid:1280935;lane:boss;label:Dripping Fangs (2 s);cd:0;major:0;
ph:1;time:299.3;tag:BOSS;spellid:1285979;lane:boss;label:Caustic Surge;cd:0;major:0;
ph:1;time:318;tag:BOSS;spellid:1280935;lane:boss;label:Dripping Fangs (2 s);cd:0;major:0;
ph:1;time:321.1;tag:BOSS;spellid:1282509;lane:boss;label:Malignant Catalyst;cd:0;major:0;
]==]

-- The Lost Explorers (Mythic), 32 boss casts – Warcraft Logs report b3R4P1BvQFq8DX6C fight 14 (264 s, a median-length top healing-ranked kill)
F[3497] = F[3497] or {}
F[3497][16] = [==[
EncounterID:3497;Difficulty:Mythic;Name:The Lost Explorers;
duration:264;
curve:dmg;step:5;unit:k;data:509,788,1321,1465,1492,1751,2216,2023,1870,1847,1545,1329,1460,1897,1814,1445,1762,2326,2635,1938,979,1249,1785,2073,2063,1552,876,1200,1479,1421,1585,1845,2082,2053,1954,1484,1132,1654,1592,1433,2025,1861,1367,1667,2170,1685,1545,1820,1493,1124,1918,2136,1320;
lanedef:boss;name:Boss;kind:boss;
ph:1;time:0;tag:BOSS;spellid:1297075;lane:boss;label:Final Ascension;cd:0;major:0;
ph:1;time:10;tag:BOSS;spellid:1296025;lane:boss;label:Blink Nova;cd:0;major:0;
ph:1;time:22;tag:BOSS;spellid:1296062;lane:boss;label:Shell Spin (4 s);cd:0;major:0;
ph:1;time:30.5;tag:BOSS;spellid:1310616;lane:boss;label:Shredding Shards;cd:0;major:0;
ph:1;time:38;tag:BOSS;spellid:1296062;lane:boss;label:Shell Spin (4 s);cd:0;major:0;
ph:1;time:41;tag:BOSS;spellid:1296025;lane:boss;label:Blink Nova;cd:0;major:0;
ph:1;time:53;tag:BOSS;spellid:1296062;lane:boss;label:Shell Spin (4 s);cd:0;major:0;
ph:1;time:78.7;tag:BOSS;spellid:1295891;lane:boss;label:Frostfire Volley (5 s);cd:0;major:0;
ph:1;time:85.6;tag:BOSS;spellid:1296062;lane:boss;label:Shell Spin (4 s);cd:0;major:0;
ph:1;time:86.6;tag:BOSS;spellid:1296025;lane:boss;label:Blink Nova;cd:0;major:0;
ph:1;time:96.1;tag:BOSS;spellid:1310616;lane:boss;label:Shredding Shards;cd:0;major:0;
ph:1;time:105.7;tag:BOSS;spellid:1295891;lane:boss;label:Frostfire Volley (5 s);cd:0;major:0;
ph:1;time:112.6;tag:BOSS;spellid:1296062;lane:boss;label:Shell Spin (4 s);cd:0;major:0;
ph:1;time:121;tag:BOSS;spellid:1310028;lane:boss;label:Relic Rupture;cd:0;major:0;
ph:1;time:123.2;tag:BOSS;spellid:1301667;lane:boss;label:Dark Whispers;cd:0;major:0;
ph:1;time:123.9;tag:BOSS;spellid:1297075;lane:boss;label:Final Ascension;cd:0;major:0;
ph:1;time:135.6;tag:BOSS;spellid:1296025;lane:boss;label:Blink Nova;cd:0;major:0;
ph:1;time:147.6;tag:BOSS;spellid:1296062;lane:boss;label:Shell Spin (4 s);cd:0;major:0;
ph:1;time:156.2;tag:BOSS;spellid:1310616;lane:boss;label:Shredding Shards;cd:0;major:0;
ph:1;time:163.6;tag:BOSS;spellid:1296062;lane:boss;label:Shell Spin (4 s);cd:0;major:0;
ph:1;time:166.6;tag:BOSS;spellid:1296025;lane:boss;label:Blink Nova;cd:0;major:0;
ph:1;time:178.6;tag:BOSS;spellid:1296062;lane:boss;label:Shell Spin (4 s);cd:0;major:0;
ph:1;time:188.2;tag:BOSS;spellid:1296975;lane:boss;label:Mor'zahi's Command;cd:0;major:0;
ph:1;time:202.4;tag:BOSS;spellid:1310028;lane:boss;label:Relic Rupture;cd:0;major:0;
ph:1;time:203.7;tag:BOSS;spellid:1296095;lane:boss;label:Mighty Thud;cd:0;major:0;
ph:1;time:207.7;tag:BOSS;spellid:1296095;lane:boss;label:Mighty Thud;cd:0;major:0;
ph:1;time:221.2;tag:BOSS;spellid:1310616;lane:boss;label:Shredding Shards;cd:0;major:0;
ph:1;time:235.7;tag:BOSS;spellid:1296095;lane:boss;label:Mighty Thud;cd:0;major:0;
ph:1;time:236.5;tag:BOSS;spellid:1310028;lane:boss;label:Relic Rupture;cd:0;major:0;
ph:1;time:239.7;tag:BOSS;spellid:1296095;lane:boss;label:Mighty Thud;cd:0;major:0;
ph:1;time:248.3;tag:BOSS;spellid:1301667;lane:boss;label:Dark Whispers;cd:0;major:0;
ph:1;time:249.1;tag:BOSS;spellid:1297075;lane:boss;label:Final Ascension;cd:0;major:0;
]==]

-- Sszorak (Mythic), 43 boss casts – Warcraft Logs report dLkXQ4MPYaC1y6B9 fight 8 (334 s, a median-length top healing-ranked kill)
F[3420] = F[3420] or {}
F[3420][16] = [==[
EncounterID:3420;Difficulty:Mythic;Name:Sszorak;
duration:334;
curve:dmg;step:5;unit:k;data:431,811,1346,1799,2261,2616,2692,2662,2283,1929,1445,1353,1522,1851,2360,2634,2457,2191,2036,1901,1597,1965,1737,1994,1991,2104,2169,1992,2118,2258,2502,2302,1748,1691,1791,1787,1558,1820,1946,2373,2404,2181,2004,1881,1669,1611,1892,1811,2054,1803,2056,1754,1569,1597,1977,2492,2448,2077,1911,1998,1676,1289,1329,1572,1941,2330,1843;
lanedef:boss;name:Boss;kind:boss;
ph:1;time:8.1;tag:BOSS;spellid:1277002;lane:boss;label:Ravage (3 s);cd:0;major:0;
ph:1;time:12.5;tag:BOSS;spellid:1287072;lane:boss;label:Tempest (3.5 s);cd:0;major:0;
ph:1;time:16.6;tag:BOSS;spellid:1277027;lane:boss;label:Mutilate (3 s);cd:0;major:0;
ph:1;time:20.5;tag:BOSS;spellid:1277002;lane:boss;label:Ravage (3 s);cd:0;major:0;
ph:1;time:24.6;tag:BOSS;spellid:1277027;lane:boss;label:Mutilate (3 s);cd:0;major:0;
ph:1;time:29;tag:BOSS;spellid:1305959;lane:boss;label:Venomous Surge;cd:0;major:0;
ph:1;time:39.8;tag:BOSS;spellid:1285425;lane:boss;label:Raging Crosswinds;cd:0;major:0;
ph:1;time:55;tag:BOSS;spellid:1277002;lane:boss;label:Ravage (3 s);cd:0;major:0;
ph:1;time:59.1;tag:BOSS;spellid:1277027;lane:boss;label:Mutilate (3 s);cd:0;major:0;
ph:1;time:63;tag:BOSS;spellid:1277002;lane:boss;label:Ravage (3 s);cd:0;major:0;
ph:1;time:67.6;tag:BOSS;spellid:1287072;lane:boss;label:Tempest (3.5 s);cd:0;major:0;
ph:1;time:71.5;tag:BOSS;spellid:1277027;lane:boss;label:Mutilate (3 s);cd:0;major:0;
ph:1;time:76.1;tag:BOSS;spellid:1305959;lane:boss;label:Venomous Surge;cd:0;major:0;
ph:1;time:86.8;tag:BOSS;spellid:1285425;lane:boss;label:Raging Crosswinds;cd:0;major:0;
ph:1;time:100.1;tag:BOSS;spellid:1286033;lane:boss;label:Dig In;cd:0;major:0;
ph:1;time:135.1;tag:BOSS;spellid:1277027;lane:boss;label:Mutilate (3 s);cd:0;major:0;
ph:1;time:139.1;tag:BOSS;spellid:1277027;lane:boss;label:Mutilate (3 s);cd:0;major:0;
ph:1;time:143.1;tag:BOSS;spellid:1277002;lane:boss;label:Ravage (3 s);cd:0;major:0;
ph:1;time:147.6;tag:BOSS;spellid:1287072;lane:boss;label:Tempest (3.5 s);cd:0;major:0;
ph:1;time:151.6;tag:BOSS;spellid:1277002;lane:boss;label:Ravage (3 s);cd:0;major:0;
ph:1;time:156.1;tag:BOSS;spellid:1305959;lane:boss;label:Venomous Surge;cd:0;major:0;
ph:1;time:166.8;tag:BOSS;spellid:1285425;lane:boss;label:Raging Crosswinds;cd:0;major:0;
ph:1;time:182.1;tag:BOSS;spellid:1277027;lane:boss;label:Mutilate (3 s);cd:0;major:0;
ph:1;time:186.6;tag:BOSS;spellid:1287072;lane:boss;label:Tempest (3.5 s);cd:0;major:0;
ph:1;time:190.6;tag:BOSS;spellid:1277002;lane:boss;label:Ravage (3 s);cd:0;major:0;
ph:1;time:194.6;tag:BOSS;spellid:1277027;lane:boss;label:Mutilate (3 s);cd:0;major:0;
ph:1;time:198.6;tag:BOSS;spellid:1277002;lane:boss;label:Ravage (3 s);cd:0;major:0;
ph:1;time:203.1;tag:BOSS;spellid:1305959;lane:boss;label:Venomous Surge;cd:0;major:0;
ph:1;time:213.8;tag:BOSS;spellid:1285425;lane:boss;label:Raging Crosswinds;cd:0;major:0;
ph:1;time:227.1;tag:BOSS;spellid:1286033;lane:boss;label:Dig In;cd:0;major:0;
ph:1;time:262.2;tag:BOSS;spellid:1277002;lane:boss;label:Ravage (3 s);cd:0;major:0;
ph:1;time:266.2;tag:BOSS;spellid:1277027;lane:boss;label:Mutilate (3 s);cd:0;major:0;
ph:1;time:270.7;tag:BOSS;spellid:1287072;lane:boss;label:Tempest (3.5 s);cd:0;major:0;
ph:1;time:274.7;tag:BOSS;spellid:1277027;lane:boss;label:Mutilate (3 s);cd:0;major:0;
ph:1;time:278.7;tag:BOSS;spellid:1277002;lane:boss;label:Ravage (3 s);cd:0;major:0;
ph:1;time:283.1;tag:BOSS;spellid:1305959;lane:boss;label:Venomous Surge;cd:0;major:0;
ph:1;time:293.9;tag:BOSS;spellid:1285425;lane:boss;label:Raging Crosswinds;cd:0;major:0;
ph:1;time:309.1;tag:BOSS;spellid:1277002;lane:boss;label:Ravage (3 s);cd:0;major:0;
ph:1;time:313.2;tag:BOSS;spellid:1277027;lane:boss;label:Mutilate (3 s);cd:0;major:0;
ph:1;time:317.1;tag:BOSS;spellid:1277002;lane:boss;label:Ravage (3 s);cd:0;major:0;
ph:1;time:321.6;tag:BOSS;spellid:1287072;lane:boss;label:Tempest (3.5 s);cd:0;major:0;
ph:1;time:325.6;tag:BOSS;spellid:1277027;lane:boss;label:Mutilate (3 s);cd:0;major:0;
ph:1;time:330.1;tag:BOSS;spellid:1305959;lane:boss;label:Venomous Surge;cd:0;major:0;
]==]

-- The Twin Fangs (Mythic), 59 boss casts – Warcraft Logs report MT6zWJpdkRFbtVr2 fight 12 (382 s, a median-length top healing-ranked kill)
F[3421] = F[3421] or {}
F[3421][16] = [==[
EncounterID:3421;Difficulty:Mythic;Name:The Twin Fangs;
duration:382;
curve:dmg;step:5;unit:k;data:602,1061,1392,1397,1445,1169,1393,1528,1961,2153,2215,2211,1821,1622,1613,1521,1584,1257,1479,1580,2050,2448,2487,2274,1875,1671,1412,1351,1362,1422,1364,1414,1639,1826,1824,1730,1515,1725,1880,2297,2406,2406,2314,2017,1964,1976,1854,1982,1693,1839,1902,2336,2422,2505,2558,2285,2049,1650,1600,1618,1690,1683,1669,1756,1901,1912,1945,1774,1999,2060,2127,2120,2380,2880,3030,2345,1473;
lanedef:boss;name:Boss;kind:boss;
ph:1;time:9;tag:BOSS;spellid:1289192;lane:boss;label:Caustic Deluge;cd:0;major:0;
ph:1;time:9;tag:BOSS;spellid:1303230;lane:boss;label:Blood Torrent;cd:0;major:0;
ph:1;time:24.5;tag:BOSS;spellid:1289092;lane:boss;label:Stone Breaker;cd:0;major:0;
ph:1;time:30.5;tag:BOSS;spellid:1289092;lane:boss;label:Stone Breaker;cd:0;major:0;
ph:1;time:36;tag:BOSS;spellid:1291404;lane:boss;label:Venomous Emergence (3 s);cd:0;major:0;
ph:1;time:42;tag:BOSS;spellid:1291478;lane:boss;label:Corrosive Spit (3.8 s);cd:0;major:0;
ph:1;time:43;tag:BOSS;spellid:1290809;lane:boss;label:Coiling Ichor (3 s);cd:0;major:0;
ph:1;time:47;tag:BOSS;spellid:1290956;lane:boss;label:Stir the Depths;cd:0;major:0;
ph:1;time:58.1;tag:BOSS;spellid:1295107;lane:boss;label:Concentrated Spittle;cd:0;major:0;
ph:1;time:61.2;tag:BOSS;spellid:1290516;lane:boss;label:Ravenous Feast (4.3 s);cd:0;major:0;
ph:1;time:62.9;tag:BOSS;spellid:1295107;lane:boss;label:Concentrated Spittle;cd:0;major:0;
ph:1;time:66.6;tag:BOSS;spellid:1295115;lane:boss;label:Clotted Bolt;cd:0;major:0;
ph:1;time:70;tag:BOSS;spellid:1289192;lane:boss;label:Caustic Deluge;cd:0;major:0;
ph:1;time:70;tag:BOSS;spellid:1303230;lane:boss;label:Blood Torrent;cd:0;major:0;
ph:1;time:85.5;tag:BOSS;spellid:1289092;lane:boss;label:Stone Breaker;cd:0;major:0;
ph:1;time:91.5;tag:BOSS;spellid:1289092;lane:boss;label:Stone Breaker;cd:0;major:0;
ph:1;time:97;tag:BOSS;spellid:1291404;lane:boss;label:Venomous Emergence (3 s);cd:0;major:0;
ph:1;time:103;tag:BOSS;spellid:1291478;lane:boss;label:Corrosive Spit (3.8 s);cd:0;major:0;
ph:1;time:104;tag:BOSS;spellid:1290809;lane:boss;label:Coiling Ichor (3 s);cd:0;major:0;
ph:1;time:108;tag:BOSS;spellid:1290956;lane:boss;label:Stir the Depths;cd:0;major:0;
ph:1;time:122.2;tag:BOSS;spellid:1290516;lane:boss;label:Ravenous Feast (4.3 s);cd:0;major:0;
ph:1;time:136;tag:BOSS;spellid:1306872;lane:boss;label:Sanguine Storm;cd:0;major:0;
ph:1;time:140;tag:BOSS;spellid:1294293;lane:boss;label:Vile Flood (4 s);cd:0;major:0;
ph:1;time:164;tag:BOSS;spellid:1289192;lane:boss;label:Caustic Deluge;cd:0;major:0;
ph:1;time:164;tag:BOSS;spellid:1303230;lane:boss;label:Blood Torrent;cd:0;major:0;
ph:1;time:171.1;tag:BOSS;spellid:1295107;lane:boss;label:Concentrated Spittle;cd:0;major:0;
ph:1;time:179.5;tag:BOSS;spellid:1289092;lane:boss;label:Stone Breaker;cd:0;major:0;
ph:1;time:185.5;tag:BOSS;spellid:1289092;lane:boss;label:Stone Breaker;cd:0;major:0;
ph:1;time:191;tag:BOSS;spellid:1291404;lane:boss;label:Venomous Emergence (3 s);cd:0;major:0;
ph:1;time:197;tag:BOSS;spellid:1291478;lane:boss;label:Corrosive Spit (3.8 s);cd:0;major:0;
ph:1;time:198;tag:BOSS;spellid:1290809;lane:boss;label:Coiling Ichor (3 s);cd:0;major:0;
ph:1;time:202;tag:BOSS;spellid:1290956;lane:boss;label:Stir the Depths;cd:0;major:0;
ph:1;time:216.3;tag:BOSS;spellid:1290516;lane:boss;label:Ravenous Feast (4.3 s);cd:0;major:0;
ph:1;time:220.9;tag:BOSS;spellid:1295107;lane:boss;label:Concentrated Spittle;cd:0;major:0;
ph:1;time:220.9;tag:BOSS;spellid:1295115;lane:boss;label:Clotted Bolt;cd:0;major:0;
ph:1;time:225;tag:BOSS;spellid:1289192;lane:boss;label:Caustic Deluge;cd:0;major:0;
ph:1;time:225;tag:BOSS;spellid:1303230;lane:boss;label:Blood Torrent;cd:0;major:0;
ph:1;time:240.5;tag:BOSS;spellid:1289092;lane:boss;label:Stone Breaker;cd:0;major:0;
ph:1;time:246.5;tag:BOSS;spellid:1289092;lane:boss;label:Stone Breaker;cd:0;major:0;
ph:1;time:252;tag:BOSS;spellid:1291404;lane:boss;label:Venomous Emergence (3 s);cd:0;major:0;
ph:1;time:258;tag:BOSS;spellid:1291478;lane:boss;label:Corrosive Spit (3.8 s);cd:0;major:0;
ph:1;time:259;tag:BOSS;spellid:1290809;lane:boss;label:Coiling Ichor (3 s);cd:0;major:0;
ph:1;time:263;tag:BOSS;spellid:1290956;lane:boss;label:Stir the Depths;cd:0;major:0;
ph:1;time:265;tag:BOSS;spellid:1291478;lane:boss;label:Corrosive Spit (3.8 s);cd:0;major:0;
ph:1;time:277.3;tag:BOSS;spellid:1290516;lane:boss;label:Ravenous Feast (4.3 s);cd:0;major:0;
ph:1;time:282.1;tag:BOSS;spellid:1295115;lane:boss;label:Clotted Bolt;cd:0;major:0;
ph:1;time:291;tag:BOSS;spellid:1306872;lane:boss;label:Sanguine Storm;cd:0;major:0;
ph:1;time:295;tag:BOSS;spellid:1294293;lane:boss;label:Vile Flood (4 s);cd:0;major:0;
ph:1;time:319.1;tag:BOSS;spellid:1289192;lane:boss;label:Caustic Deluge;cd:0;major:0;
ph:1;time:319.1;tag:BOSS;spellid:1303230;lane:boss;label:Blood Torrent;cd:0;major:0;
ph:1;time:327;tag:BOSS;spellid:1295107;lane:boss;label:Concentrated Spittle;cd:0;major:0;
ph:1;time:334.5;tag:BOSS;spellid:1289092;lane:boss;label:Stone Breaker;cd:0;major:0;
ph:1;time:340.5;tag:BOSS;spellid:1289092;lane:boss;label:Stone Breaker;cd:0;major:0;
ph:1;time:346.1;tag:BOSS;spellid:1291404;lane:boss;label:Venomous Emergence (3 s);cd:0;major:0;
ph:1;time:352.1;tag:BOSS;spellid:1291478;lane:boss;label:Corrosive Spit (3.8 s);cd:0;major:0;
ph:1;time:353.1;tag:BOSS;spellid:1290809;lane:boss;label:Coiling Ichor (3 s);cd:0;major:0;
ph:1;time:371.3;tag:BOSS;spellid:1290516;lane:boss;label:Ravenous Feast (4.3 s);cd:0;major:0;
ph:1;time:376.6;tag:BOSS;spellid:1295115;lane:boss;label:Clotted Bolt;cd:0;major:0;
ph:1;time:380;tag:BOSS;spellid:1303230;lane:boss;label:Blood Torrent;cd:0;major:0;
]==]

-- The Coiled Altar (Mythic), 79 boss casts – Warcraft Logs report zX2A8jNvq7pbfmF6 fight 1 (589 s, a median-length top healing-ranked kill)
F[3429] = F[3429] or {}
F[3429][16] = [==[
EncounterID:3429;Difficulty:Mythic;Name:The Coiled Altar;
duration:589;
curve:dmg;step:5;unit:k;data:900,1329,1614,2026,2082,1981,2020,2100,1846,1832,2343,2725,2594,2403,2404,2083,1812,1964,2233,2446,2777,2931,2841,2643,2393,2293,2152,2414,2672,2558,2264,2109,2349,2429,2464,2456,2378,2038,1819,1849,1861,2040,2004,1967,1912,2015,2017,2107,2353,2337,2324,2184,2074,1750,1681,1720,1951,1961,2087,1986,1885,1748,1810,1860,2044,2225,2189,2201,2047,1876,1693,1683,1692,1895,1919,1646,1607,1676,1663,1828,2258,2570,2190,1649,1419,1108,1011,1372,1728,1964,2242,2519,2330,2245,2114,1930,1819,2145,2227,2223,2240,2139,1885,1865,1980,1983,2026,2148,2200,2236,2413,2994,3526,3599,3593,3424,2417,1416,1039;
lanedef:boss;name:Boss;kind:boss;
ph:1;time:0;tag:BOSS;spellid:1282487;lane:boss;label:Fangs of the Coiled Altar;cd:0;major:0;
ph:1;time:2;tag:BOSS;spellid:1299960;lane:boss;label:Toxic Deluge;cd:0;major:0;
ph:1;time:5.7;tag:BOSS;spellid:1283290;lane:boss;label:Noxious Ground;cd:0;major:0;
ph:1;time:16.2;tag:BOSS;spellid:1283290;lane:boss;label:Noxious Ground;cd:0;major:0;
ph:1;time:23;tag:BOSS;spellid:1299684;lane:boss;label:Sever (3 s);cd:0;major:0;
ph:1;time:30;tag:BOSS;spellid:1282287;lane:boss;label:Venomfang (2 s);cd:0;major:0;
ph:1;time:40;tag:BOSS;spellid:1299684;lane:boss;label:Sever (3 s);cd:0;major:0;
ph:1;time:43;tag:BOSS;spellid:1283485;lane:boss;label:Guillotine;cd:0;major:0;
ph:1;time:45;tag:BOSS;spellid:1299960;lane:boss;label:Toxic Deluge;cd:0;major:0;
ph:1;time:60;tag:BOSS;spellid:1299684;lane:boss;label:Sever (3 s);cd:0;major:0;
ph:1;time:65;tag:BOSS;spellid:1282287;lane:boss;label:Venomfang (2 s);cd:0;major:0;
ph:1;time:77;tag:BOSS;spellid:1299684;lane:boss;label:Sever (3 s);cd:0;major:0;
ph:1;time:85;tag:BOSS;spellid:1282487;lane:boss;label:Fangs of the Coiled Altar;cd:0;major:0;
ph:1;time:87;tag:BOSS;spellid:1299960;lane:boss;label:Toxic Deluge;cd:0;major:0;
ph:1;time:90.7;tag:BOSS;spellid:1283290;lane:boss;label:Noxious Ground;cd:0;major:0;
ph:1;time:94.4;tag:BOSS;spellid:1283290;lane:boss;label:Noxious Ground;cd:0;major:0;
ph:1;time:98.4;tag:BOSS;spellid:1283290;lane:boss;label:Noxious Ground;cd:0;major:0;
ph:1;time:101.5;tag:BOSS;spellid:1283290;lane:boss;label:Noxious Ground;cd:0;major:0;
ph:1;time:106.2;tag:BOSS;spellid:1283290;lane:boss;label:Noxious Ground;cd:0;major:0;
ph:1;time:108.1;tag:BOSS;spellid:1299684;lane:boss;label:Sever (3 s);cd:0;major:0;
ph:1;time:111;tag:BOSS;spellid:1283290;lane:boss;label:Noxious Ground;cd:0;major:0;
ph:1;time:114.2;tag:BOSS;spellid:1283290;lane:boss;label:Noxious Ground;cd:0;major:0;
ph:1;time:115;tag:BOSS;spellid:1282287;lane:boss;label:Venomfang (2 s);cd:0;major:0;
ph:1;time:125;tag:BOSS;spellid:1299684;lane:boss;label:Sever (3 s);cd:0;major:0;
ph:1;time:128;tag:BOSS;spellid:1283485;lane:boss;label:Guillotine;cd:0;major:0;
ph:1;time:130;tag:BOSS;spellid:1299960;lane:boss;label:Toxic Deluge;cd:0;major:0;
ph:1;time:145;tag:BOSS;spellid:1299684;lane:boss;label:Sever (3 s);cd:0;major:0;
ph:1;time:150;tag:BOSS;spellid:1282287;lane:boss;label:Venomfang (2 s);cd:0;major:0;
ph:1;time:162;tag:BOSS;spellid:1299684;lane:boss;label:Sever (3 s);cd:0;major:0;
ph:1;time:170;tag:BOSS;spellid:1282487;lane:boss;label:Fangs of the Coiled Altar;cd:0;major:0;
ph:1;time:178.6;tag:BOSS;spellid:1288624;lane:boss;label:Dreadful Presence;cd:0;major:0;
ph:1;time:186.1;tag:BOSS;spellid:1285643;lane:boss;label:Dreadmarch (2 s);cd:0;major:0;
ph:1;time:191.6;tag:BOSS;spellid:1286441;lane:boss;label:Spiritcackle;cd:0;major:0;
ph:1;time:196.1;tag:BOSS;spellid:1308311;lane:boss;label:Retaliatory Malice;cd:0;major:0;
ph:1;time:198.6;tag:BOSS;spellid:1310882;lane:boss;label:Gloombomb (2 s);cd:0;major:0;
ph:1;time:216.6;tag:BOSS;spellid:1286620;lane:boss;label:Soul Sever (4 s);cd:0;major:0;
ph:1;time:222.7;tag:BOSS;spellid:1285643;lane:boss;label:Dreadmarch (2 s);cd:0;major:0;
ph:1;time:224.6;tag:BOSS;spellid:1286441;lane:boss;label:Spiritcackle;cd:0;major:0;
ph:1;time:229.1;tag:BOSS;spellid:1308311;lane:boss;label:Retaliatory Malice;cd:0;major:0;
ph:1;time:235.6;tag:BOSS;spellid:1310882;lane:boss;label:Gloombomb (2 s);cd:0;major:0;
ph:1;time:247.6;tag:BOSS;spellid:1286620;lane:boss;label:Soul Sever (4 s);cd:0;major:0;
ph:1;time:271.1;tag:BOSS;spellid:1285643;lane:boss;label:Dreadmarch (2 s);cd:0;major:0;
ph:1;time:276.6;tag:BOSS;spellid:1286441;lane:boss;label:Spiritcackle;cd:0;major:0;
ph:1;time:281.1;tag:BOSS;spellid:1308311;lane:boss;label:Retaliatory Malice;cd:0;major:0;
ph:1;time:283.6;tag:BOSS;spellid:1310882;lane:boss;label:Gloombomb (2 s);cd:0;major:0;
ph:1;time:301.6;tag:BOSS;spellid:1286620;lane:boss;label:Soul Sever (4 s);cd:0;major:0;
ph:1;time:307.6;tag:BOSS;spellid:1285643;lane:boss;label:Dreadmarch (2 s);cd:0;major:0;
ph:1;time:309.6;tag:BOSS;spellid:1286441;lane:boss;label:Spiritcackle;cd:0;major:0;
ph:1;time:314.1;tag:BOSS;spellid:1308311;lane:boss;label:Retaliatory Malice;cd:0;major:0;
ph:1;time:320.6;tag:BOSS;spellid:1310882;lane:boss;label:Gloombomb (2 s);cd:0;major:0;
ph:1;time:332.6;tag:BOSS;spellid:1286620;lane:boss;label:Soul Sever (4 s);cd:0;major:0;
ph:1;time:356.1;tag:BOSS;spellid:1285643;lane:boss;label:Dreadmarch (2 s);cd:0;major:0;
ph:1;time:361.6;tag:BOSS;spellid:1286441;lane:boss;label:Spiritcackle;cd:0;major:0;
ph:1;time:366.1;tag:BOSS;spellid:1308311;lane:boss;label:Retaliatory Malice;cd:0;major:0;
ph:1;time:368.6;tag:BOSS;spellid:1310882;lane:boss;label:Gloombomb (2 s);cd:0;major:0;
ph:1;time:382.9;tag:BOSS;spellid:1304028;lane:boss;label:Deathguard;cd:0;major:0;
ph:1;time:385.8;tag:BOSS;spellid:1304032;lane:boss;label:Soulbinding;cd:0;major:0;
ph:1;time:386;tag:BOSS;spellid:1304498;lane:boss;label:Ghastly Regeneration;cd:0;major:0;
ph:1;time:423.5;tag:BOSS;spellid:1298381;lane:boss;label:Defilement of the Coiled Altar;cd:0;major:0;
ph:1;time:425.7;tag:BOSS;spellid:1299960;lane:boss;label:Toxic Deluge;cd:0;major:0;
ph:1;time:440.2;tag:BOSS;spellid:1299266;lane:boss;label:Grim Guillotine;cd:0;major:0;
ph:1;time:449.9;tag:BOSS;spellid:1310882;lane:boss;label:Gloombomb (2 s);cd:0;major:0;
ph:1;time:458.7;tag:BOSS;spellid:1307292;lane:boss;label:Blighted Sever (3 s);cd:0;major:0;
ph:1;time:466.8;tag:BOSS;spellid:1299960;lane:boss;label:Toxic Deluge;cd:0;major:0;
ph:1;time:480.1;tag:BOSS;spellid:1285643;lane:boss;label:Dreadmarch (2 s);cd:0;major:0;
ph:1;time:485.7;tag:BOSS;spellid:1286441;lane:boss;label:Spiritcackle;cd:0;major:0;
ph:1;time:489.8;tag:BOSS;spellid:1307292;lane:boss;label:Blighted Sever (3 s);cd:0;major:0;
ph:1;time:490.2;tag:BOSS;spellid:1308311;lane:boss;label:Retaliatory Malice;cd:0;major:0;
ph:1;time:494.4;tag:BOSS;spellid:1310882;lane:boss;label:Gloombomb (2 s);cd:0;major:0;
ph:1;time:504.6;tag:BOSS;spellid:1299266;lane:boss;label:Grim Guillotine;cd:0;major:0;
ph:1;time:523.1;tag:BOSS;spellid:1307292;lane:boss;label:Blighted Sever (3 s);cd:0;major:0;
ph:1;time:525.7;tag:BOSS;spellid:1298381;lane:boss;label:Defilement of the Coiled Altar;cd:0;major:0;
ph:1;time:526.8;tag:BOSS;spellid:1299960;lane:boss;label:Toxic Deluge;cd:0;major:0;
ph:1;time:532.1;tag:BOSS;spellid:1310882;lane:boss;label:Gloombomb (2 s);cd:0;major:0;
ph:1;time:559.8;tag:BOSS;spellid:1307292;lane:boss;label:Blighted Sever (3 s);cd:0;major:0;
ph:1;time:568;tag:BOSS;spellid:1299960;lane:boss;label:Toxic Deluge;cd:0;major:0;
ph:1;time:577.5;tag:BOSS;spellid:1285643;lane:boss;label:Dreadmarch (2 s);cd:0;major:0;
ph:1;time:582.4;tag:BOSS;spellid:1286441;lane:boss;label:Spiritcackle;cd:0;major:0;
ph:1;time:586.9;tag:BOSS;spellid:1308311;lane:boss;label:Retaliatory Malice;cd:0;major:0;
]==]

-- Ula'tek (Mythic), 38 boss casts – Warcraft Logs report 3z9kfZH6cFtBRpPd fight 4 (599 s, a median-length top healing-ranked kill)
F[3492] = F[3492] or {}
F[3492][16] = [==[
EncounterID:3492;Difficulty:Mythic;Name:Ula'tek;
duration:599;
curve:dmg;step:5;unit:k;data:526,878,1168,1565,1749,2015,2373,2721,2714,2791,2596,2222,1952,1732,1555,1652,1799,2019,2310,2773,3060,3072,2948,2823,2736,2675,2725,2893,2969,2986,2944,2853,2529,2363,2075,1893,1881,2004,2146,2255,2489,2928,2858,2949,2963,2751,2345,2445,2277,2223,2283,2278,2216,2230,2221,2224,2495,2757,3117,3314,3646,3282,2911,2410,2214,2035,2371,2926,3668,3609,3206,2874,2329,1576,1507,1789,1862,1901,2071,2312,2304,2285,2318,2328,2314,2395,2521,2545,2500,2408,2211,2179,2377,2455,2507,2772,2954,2958,3026,2973,2752,2714,2812,2794,2942,3205,3361,3212,3245,3031,2770,2390,2298,2169,2380,3018,3275,3185,2702,2109;
lanedef:boss;name:Boss;kind:boss;
ph:1;time:5;tag:BOSS;spellid:1304012;lane:boss;label:Call of the Serpent (eggs) (4 s);cd:0;major:0;
ph:1;time:27;tag:BOSS;spellid:1298367;lane:boss;label:Mother's Wrath - tank knockback (5 s);cd:0;major:0;
ph:1;time:40.4;tag:BOSS;spellid:1299010;lane:boss;label:Spectral Coils soak (intermission) (4 s);cd:0;major:0;
ph:1;time:43.7;tag:BOSS;spellid:1299010;lane:boss;label:Spectral Coils soak (intermission) (4 s);cd:0;major:0;
ph:1;time:49;tag:BOSS;spellid:1296301;lane:boss;label:Mephitic Thrash (sweep) (4 s);cd:0;major:0;
ph:1;time:56;tag:BOSS;spellid:1319282;lane:boss;label:Caustic Waves (6 s);cd:0;major:0;
ph:1;time:75;tag:BOSS;spellid:1304012;lane:boss;label:Call of the Serpent (eggs) (4 s);cd:0;major:0;
ph:1;time:79.4;tag:BOSS;spellid:1292566;lane:boss;label:Submerge (2.4 s);cd:0;major:0;
ph:1;time:97;tag:BOSS;spellid:1298367;lane:boss;label:Mother's Wrath - tank knockback (5 s);cd:0;major:0;
ph:1;time:106;tag:BOSS;spellid:1296301;lane:boss;label:Mephitic Thrash (sweep) (4 s);cd:0;major:0;
ph:1;time:113;tag:BOSS;spellid:1319282;lane:boss;label:Caustic Waves (6 s);cd:0;major:0;
ph:1;time:134.4;tag:BOSS;spellid:1299010;lane:boss;label:Spectral Coils soak (intermission) (4 s);cd:0;major:0;
ph:1;time:137.6;tag:BOSS;spellid:1299010;lane:boss;label:Spectral Coils soak (intermission) (4 s);cd:0;major:0;
ph:1;time:145.5;tag:BOSS;spellid:1286860;lane:boss;label:Rage of the Shackled (6.5 s);cd:0;major:0;
ph:1;time:180.3;tag:BOSS;spellid:1301213;lane:boss;label:Shadow Molt (Warden teleport) ~ (2.3 s);cd:0;major:0;
ph:1;time:183.8;tag:BOSS;spellid:1302950;lane:boss;label:Writhing Gestation ~ (3 s);cd:0;major:0;
ph:1;time:198.3;tag:BOSS;spellid:1301117;lane:boss;label:Grasping Fangs (tethers) ~ (2 s);cd:0;major:0;
ph:1;time:271.2;tag:BOSS;spellid:1303410;lane:boss;label:Defect: Weakened ~;cd:0;major:0;
ph:1;time:291.6;tag:BOSS;spellid:1305709;lane:boss;label:Desperate Thrash ~ (3 s);cd:0;major:0;
ph:1;time:294.6;tag:BOSS;spellid:1286860;lane:boss;label:Rage of the Shackled (6.5 s);cd:0;major:0;
ph:1;time:309.8;tag:BOSS;spellid:1305709;lane:boss;label:Desperate Thrash ~ (3 s);cd:0;major:0;
ph:1;time:336.7;tag:BOSS;spellid:1299010;lane:boss;label:Spectral Coils soak (intermission) (4 s);cd:0;major:0;
ph:1;time:343.1;tag:BOSS;spellid:1299010;lane:boss;label:Spectral Coils soak (intermission) (4 s);cd:0;major:0;
ph:1;time:348.8;tag:BOSS;spellid:1299010;lane:boss;label:Spectral Coils soak (intermission) (4 s);cd:0;major:0;
ph:1;time:352.8;tag:BOSS;spellid:1299010;lane:boss;label:Spectral Coils soak (intermission) (4 s);cd:0;major:0;
ph:1;time:387.2;tag:BOSS;spellid:1298367;lane:boss;label:Mother's Wrath - tank knockback (5 s);cd:0;major:0;
ph:1;time:402.3;tag:BOSS;spellid:1295905;lane:boss;label:Serpent's Bite (soaks) (5 s);cd:0;major:0;
ph:1;time:440.2;tag:BOSS;spellid:1315341;lane:boss;label:Circling Prey (platform break) (8 s);cd:0;major:0;
ph:1;time:442.7;tag:BOSS;spellid:1301512;lane:boss;label:Submerge (2.4 s);cd:0;major:0;
ph:1;time:466.2;tag:BOSS;spellid:1295905;lane:boss;label:Serpent's Bite (soaks) (5 s);cd:0;major:0;
ph:1;time:472.3;tag:BOSS;spellid:1298367;lane:boss;label:Mother's Wrath - tank knockback (5 s);cd:0;major:0;
ph:1;time:491.2;tag:BOSS;spellid:1315341;lane:boss;label:Circling Prey (platform break) (8 s);cd:0;major:0;
ph:1;time:494.6;tag:BOSS;spellid:1301512;lane:boss;label:Submerge (2.4 s);cd:0;major:0;
ph:1;time:540.2;tag:BOSS;spellid:1298367;lane:boss;label:Mother's Wrath - tank knockback (5 s);cd:0;major:0;
ph:1;time:552.2;tag:BOSS;spellid:1315341;lane:boss;label:Circling Prey (platform break) (8 s);cd:0;major:0;
ph:1;time:554.7;tag:BOSS;spellid:1301512;lane:boss;label:Submerge (2.4 s);cd:0;major:0;
ph:1;time:570.2;tag:BOSS;spellid:1295905;lane:boss;label:Serpent's Bite (soaks) (5 s);cd:0;major:0;
ph:1;time:583.8;tag:BOSS;spellid:1286860;lane:boss;label:Rage of the Shackled (6.5 s);cd:0;major:0;
]==]
