/*
 * SPENDU.C  -  Super Pendu  -  Version 1.1
 *
 * Jeu du pendu pour Zenith Z-89 / Heathkit H-89, terminal Z-19 Heath VT52.
 * Caracteres graphiques H-19A (source : manuel pp.69-70).
 * Hall of Fame sauvegarde dans SPENDU.DAT sur la disquette.
 *
 * Score par manche (mot trouve uniquement) :
 *   ((MAX_ERR - erreurs) * 900) / MAX_ERR  +  longueur_mot * 10
 * Maximum par manche : ~1020  |  Maximum 5 manches : ~5100
 *
 * Compilation :
 *   zcc -mz80 +cpm -subtype=hz89 -o SPENDU.COM spendu.c
 *
 * Par Claude I.A. & RomaX ManiaX
 */

#include <stdio.h>

/* ===================================================================
   Lecture caractere sans echo : BDOS fonction 6 (Direct Console I/O)
   Retourne 0 si aucun caractere disponible, sinon le code ASCII.
   Boucle jusqu'a obtenir un caractere.
   =================================================================== */
static int read_noecho(void)
{
    int c;
    do { c = bdos(6, 0xFF); } while (c == 0);
    return c;
}

/* ===================================================================
   Sequences d'echappement Z-19 Heath VT52
   =================================================================== */
#define CLS()      fputs("\033E",  stdout)
#define GOTO(r,c)  do { putchar(27); putchar('Y'); putchar((r)+32); putchar((c)+32); } while(0)
#define REV_ON()   fputs("\033p",  stdout)
#define REV_OFF()  fputs("\033q",  stdout)
#define CLREOL()   fputs("\033K",  stdout)
#define GFX_ON()   fputs("\033F",  stdout)
#define GFX_OFF()  fputs("\033G",  stdout)
#define CUR_OFF()  fputs("\033x5", stdout)
#define CUR_ON()   fputs("\033y5", stdout)

/* ===================================================================
   Caracteres graphiques H-19A
   Decimal ASCII -> Symbole
    96  `  ->  ┃    97  a  ->  ━    99  c  ->  ┓
   100  d  ->  ┛   101  e  ->  ┗   102  f  ->  ┏
   105  i  ->  ▒   116  t  ->  ┫   117  u  ->  ┻
   118  v  ->  ┣   120  x  ->  ╱   121  y  ->  ╲
   =================================================================== */
#define G_V   '\x60'  /* ┃ */
#define G_H   'a'     /* ━ */
#define G_TR  'c'     /* ┓ */
#define G_BR  'd'     /* ┛ */
#define G_BL  'e'     /* ┗ */
#define G_TL  'f'     /* ┏ */
#define G_SH  'i'     /* ▒ */
#define G_RT  't'     /* ┫ */
#define G_BT  'u'     /* ┻ */
#define G_LT  'v'     /* ┣ */
#define G_DL  'x'     /* ╱ */
#define G_DR  'y'     /* ╲ */

/* ===================================================================
   Layout ecran 80x24
   Row  0    : titre (reverse video)
   Cols 0-21 : zone potence, rows 4-14
   Cols 22-77: panneau jeu,  rows 3-15
   Row 17    : bande ▒▒▒
   Row 19    : invite saisie
   Row 20    : messages
   Row 23    : barre statut (reverse video)
   =================================================================== */
#define G_PCOL   4    /* col pilier vertical potence    */
#define G_RCOL  15    /* col corde / corps              */
#define G_BROW   4    /* row traverse haute             */
#define G_GROW  14    /* row base (sol)                 */
#define G_BLC    2    /* col gauche base                */
#define G_BRC   20    /* col droite base                */

#define P_L     22    /* panneau : col bord gauche      */
#define P_R     77    /* panneau : col bord droit       */
#define P_W     54    /* panneau : largeur interieure   */

#define PR_TOP    3   /* rows du panneau de jeu         */
#define PR_WLBL   4
#define PR_WSEP   5
#define PR_WORD   6
#define PR_WNFO   7
#define PR_LSEP   8
#define PR_LLBL   9
#define PR_LSEP2 10
#define PR_LTR1  11
#define PR_LTR2  12
#define PR_ESEP  13
#define PR_ERR   14
#define PR_BOT   15

#define ROW_SHADE  17 /* bande decorative ▒▒▒           */
#define ROW_INPUT  19 /* invite saisie lettre           */
#define ROW_MSG    20 /* zone messages jeu              */

/* ===================================================================
   Constantes de jeu
   =================================================================== */
#define NB_MANCHES   5
#define MAX_ERR      6
#define MOT_MAX     18
#define INV_COL     19  /* col echo lettre : fleche(1) + " Votre lettre : "(16) + 2 */

/* ===================================================================
   Hall of Fame  -  fichier SPENDU.DAT
   Format : 5 entrees x 19 octets
     17 octets : nom (null-termine, zero-padde)
      2 octets : score (little-endian, unsigned 16 bits)
   =================================================================== */
#define HOF_FILE    "SPENDU.DAT"
#define HOF_SIZE    5
#define HOF_NAMELEN 16

typedef struct {
    char     nom[HOF_NAMELEN + 1];
    unsigned score;
} HofEntry;

/* ===================================================================
   Dictionnaire : 1500 mots
   =================================================================== */
#define NB_MOTS     1500

static const char MOTS_DATA[] =
    "ORDINATEUR\0MEMOIRE\0CLAVIER\0TERMINAL\0FICHIER\0REGISTRE\0"
    "VARIABLE\0FONCTION\0BOUCLE\0DISQUETTE\0BINAIRE\0CIRCUIT\0"
    "LOGICIEL\0MATERIEL\0INTERFACE\0PROTOCOLE\0RESEAU\0COMMANDE\0"
    "ARGUMENT\0STRUCTURE\0OCTETS\0ADRESSE\0SEGMENT\0VECTEUR\0"
    "PILOTE\0TAMPON\0IMPRIMANTE\0ARITHMETIQUE\0ALGORITHME\0INTERRUPTION\0"
    "PROGRAMME\0ASSEMBLEUR\0BISON\0BUFFLE\0CASTOR\0CHACAL\0"
    "CHEVAL\0COLOMBE\0CONDOR\0CORBEAU\0DINDON\0ELEPHANT\0"
    "FAUCON\0FLAMANT\0FOURMI\0GORILLE\0GRENOUILLE\0HIBOU\0"
    "HIRONDELLE\0KANGOUROU\0LAPIN\0LEOPARD\0LIBELLULE\0LIEVRE\0"
    "LOUTRE\0MEDUSE\0MOINEAU\0MOUETTE\0MOUTON\0ORQUE\0"
    "PANDA\0PAPILLON\0PERROQUET\0PHOQUE\0PIEUVRE\0PIGEON\0"
    "PIRANHA\0PYTHON\0RENARD\0REQUIN\0SERPENT\0TIGRE\0"
    "TOUCAN\0VAUTOUR\0VIPERE\0ZEBRE\0GUPPY\0HUPPE\0"
    "MERLE\0MULOT\0RATON\0TATOU\0CABRI\0CAIMAN\0"
    "CALMAR\0BELETTE\0FRELON\0MERLAN\0MURENE\0OCELOT\0"
    "CARIBOU\0COBAYE\0ECUREUIL\0ESCARGOT\0ESPADON\0FAUVETTE\0"
    "GOELAND\0HARFANG\0IGUANE\0LEZARD\0LINOTTE\0MACAQUE\0"
    "MAINATE\0PHASME\0POULPE\0SARDINE\0SEICHE\0SPATULE\0"
    "TERMITE\0ALLIGATOR\0ANACONDA\0ANTILOPE\0AUTRUCHE\0BLAIREAU\0"
    "MESANGE\0RAINETTE\0CHEVREUIL\0SALAMANDRE\0SANGLIER\0SURICATE\0"
    "HIPPOCAMPE\0KINKAJOU\0MUSARAIGNE\0ORNITHORYNQUE\0PHENICOPTERE\0WOMBAT\0"
    "XIPHIAS\0KOALA\0WALLABY\0HOMARD\0CROCODILE\0HANNETON\0"
    "LAMPROIE\0CIGALE\0RHINOCEROS\0ACACIA\0ALGUES\0ANEMONE\0"
    "BAMBOU\0BAOBAB\0BRUYERE\0CACTUS\0CHARDON\0COQUELICOT\0"
    "EGLANTINE\0FOUGERE\0FRAMBOISE\0GENEVRIER\0GLYCINE\0GRENADIER\0"
    "JASMIN\0JONQUILLE\0LAURIER\0LAVANDE\0LILAS\0LOTUS\0"
    "MAGNOLIA\0MARGUERITE\0MIMOSA\0MYOSOTIS\0NOISETTE\0OSEILLE\0"
    "PAQUERETTE\0PIVOINE\0PLATANE\0POMMIER\0PRIMEVERE\0PRUNIER\0"
    "ROSIER\0TULIPE\0VIOLETTE\0AGAVE\0ERABLE\0ORTIE\0"
    "SAUGE\0TROENE\0CISTE\0CYTISE\0DAHLIA\0GENET\0"
    "HYSOPE\0LANTANA\0LUPULIN\0PERVENCHE\0RONCE\0TAMARIS\0"
    "THUYA\0VALERIAN\0ABIME\0ETANG\0FJORD\0RAVIN\0"
    "BUTTE\0BASSIN\0DESERT\0GROTTE\0JUNGLE\0LAGUNE\0"
    "MAQUIS\0PLAINE\0SOURCE\0STEPPE\0VALLEE\0COLLINE\0"
    "ICEBERG\0MONTAGNE\0PAYSAGE\0PLATEAU\0PRAIRIE\0RIVIERE\0"
    "ROCHER\0SAVANE\0ARCHIPEL\0ESTUAIRE\0MERIDIEN\0CONTINENT\0"
    "BIOSPHERE\0BANQUISE\0LAPIAZ\0CRIQUE\0MORAINE\0MARAIS\0"
    "SUREAU\0CAMELIA\0LIERRE\0FRAISIER\0AFRIQUE\0ALSACE\0"
    "AMAZONE\0ANDALOUSIE\0ATLANTIQUE\0AUSTRALIE\0AUTRICHE\0AUVERGNE\0"
    "BORDEAUX\0BRETAGNE\0CAMARGUE\0CAUCASE\0CEVENNES\0CHAMPAGNE\0"
    "ECOSSE\0ESPAGNE\0FINLANDE\0FLORENCE\0HIMALAYA\0HONGRIE\0"
    "ISLANDE\0LAPONIE\0LORRAINE\0MEXIQUE\0MONGOLIE\0MOSCOU\0"
    "NORMANDIE\0NORVEGE\0OCCITANIE\0PACIFIQUE\0PICARDIE\0PORTUGAL\0"
    "SIBERIE\0SICILE\0SLOVENIE\0SUISSE\0TAHITI\0TOSCANE\0"
    "TOURAINE\0UKRAINE\0VIETNAM\0MARSEILLE\0RUSSIE\0ABRICOT\0"
    "AMANDE\0ANANAS\0ARTICHAUT\0AUBERGINE\0AVOCAT\0BROCOLI\0"
    "BRUGNON\0CAMEMBERT\0CANNELLE\0CAROTTE\0CERISE\0CHAMPIGNON\0"
    "CHOCOLAT\0CLEMENTINE\0COURGETTE\0CREVETTE\0FENOUIL\0FRAISE\0"
    "FROMAGE\0GALETTE\0GINGEMBRE\0MACARONI\0MANGUE\0MOUTARDE\0"
    "MUSCADE\0OLIVE\0ORANGE\0ORIGAN\0PAPAYE\0PECHE\0"
    "PERSIL\0PISTACHE\0POTIRON\0RAISIN\0RATATOUILLE\0ROMARIN\0"
    "TRUFFE\0VANILLE\0AGNEAU\0CIDRE\0CITRON\0DAUBE\0"
    "FARCE\0GATEAU\0GRATIN\0KEBAB\0NOUILLE\0PAELLA\0"
    "POTAGE\0POULET\0BISCUIT\0BOISSON\0CARAMEL\0COMPOTE\0"
    "CROUTON\0ECLAIR\0KETCHUP\0MAGRET\0MERINGUE\0POIVRON\0"
    "SOUFFLE\0TARTINE\0TERRINE\0BAVAROIS\0CONSOMME\0DEJEUNER\0"
    "FEUILLETE\0JULIENNE\0LIMONADE\0MACARON\0SAUCISSE\0TAPENADE\0"
    "BAGUETTE\0CHARCUTERIE\0VINAIGRETTE\0PROFITEROLE\0MILLEFEUILLE\0YAKITORI\0"
    "KOUGLOF\0SORBET\0FRICASSEE\0LENTILLE\0GROSEILLE\0ASPERGE\0"
    "AURORE\0AZOTE\0BASALTE\0CARBONE\0CELLULE\0CHIMIE\0"
    "CHLORE\0COMETE\0COSMOS\0CRISTAL\0ELECTRON\0ENZYME\0"
    "EROSION\0FOUDRE\0FRACTAL\0GALAXIE\0GLACIER\0GRANITE\0"
    "GRAVITE\0INERTIE\0ISOTOPE\0LASER\0LITHIUM\0MAREE\0"
    "MATIERE\0METEORITE\0MINERAL\0MITOSE\0NEUTRON\0NUCLEUS\0"
    "PHOTON\0PLASMA\0PROTON\0SEISME\0SODIUM\0SOLEIL\0"
    "SPECTRE\0STRATUS\0TECTONIQUE\0TEMPETE\0TONNERRE\0TORNADE\0"
    "TSUNAMI\0TYPHON\0VAPEUR\0VOLCAN\0NOYAU\0SPORE\0"
    "XENON\0ACIDE\0AXIOME\0AZIMUT\0FLUIDE\0LACUNE\0"
    "LIPIDE\0OXYDE\0ALBEDO\0CALCUL\0COULEUR\0DENSITE\0"
    "EMBRYON\0ENERGIE\0ESPECE\0FOSSILE\0FUSION\0HABITAT\0"
    "LIGNITE\0METHANE\0MICROBE\0OSMOSE\0OXYGENE\0PEPTIDE\0"
    "POLLEN\0ZYMASE\0NUAGE\0AEROSOL\0ANALYSE\0CAVERNE\0"
    "COLLAGENE\0DOMAINE\0FISSION\0FLUORURE\0GEOLOGIE\0GENETIQUE\0"
    "KERATINE\0MANGANESE\0MEMBRANE\0MUTATION\0NUCLEOTIDE\0NUTRIMENT\0"
    "PARADIGME\0PLANCTON\0POLYMERE\0POTASSIUM\0PROTEINE\0REACTION\0"
    "RIBOSOME\0SYNAPSE\0VITESSE\0ANTICORPS\0ANTIDOTE\0BACTERIE\0"
    "COLLISION\0DIFFUSION\0ECOSYSTEME\0ELECTRICITE\0ELECTROLYTE\0FERMENTATION\0"
    "INFRAROUGE\0INTERACTION\0LYMPHOCYTE\0MAGNETISME\0MORPHOLOGIE\0RADIOACTIVITE\0"
    "STALAGMITE\0VANADIUM\0HYDROGENE\0SILICIUM\0ARDOISE\0ASPHALTE\0"
    "CALCAIRE\0OBSIDIENNE\0PARCHEMIN\0FELDSPATH\0TRACHYTE\0ZIRCON\0"
    "KAOLIN\0SCHISTE\0DIORITE\0COMBUSTION\0LUMIERE\0SOLUTION\0"
    "HORMONE\0ATOME\0SILICE\0PARASITE\0BIOME\0BADMINTON\0"
    "BASEBALL\0BASKETBALL\0BIATHLON\0BOBSLEIGH\0CRICKET\0CYCLISME\0"
    "ESCRIME\0FOOTBALL\0FRISBEE\0HANDBALL\0KARATE\0KAYAK\0"
    "MARATHON\0PELOTE\0PLONGEON\0SLALOM\0TENNIS\0TRIATHLON\0"
    "VOILE\0LUTTE\0PIVOT\0SABRE\0JOUTE\0KENDO\0"
    "LASSO\0PALME\0CATCH\0BARRE\0CHUTE\0FINALE\0"
    "DISQUE\0SPRINT\0COURSE\0RELAIS\0ESQUIVE\0HALTERE\0"
    "FLEURET\0PELOTON\0POUTRE\0RAMEUR\0EPREUVE\0ACROBATIE\0"
    "ESTOCADE\0EXERCICE\0FREESTYLE\0HIPPISME\0MEDAILLE\0PENTATHLON\0"
    "RAQUETTE\0TRACTION\0TRAMPOLINE\0COMPETITION\0AVIRON\0ATHLETISME\0"
    "PLONGEOIR\0AQUARELLE\0CERAMIQUE\0COMEDIE\0DESSIN\0ESTAMPE\0"
    "GALERIE\0GRAVURE\0MAQUETTE\0MASQUE\0MINIATURE\0MOSAIQUE\0"
    "MUSEE\0PANORAMA\0PASTEL\0POESIE\0PORTRAIT\0POTERIE\0"
    "SATIRE\0THEATRE\0TRAGEDIE\0VITRAIL\0SCULPTURE\0ABDOMEN\0"
    "ARTERE\0CERVEAU\0CHEVILLE\0CLAVICULE\0CUISSE\0EPAULE\0"
    "ESTOMAC\0GANGLION\0GLANDE\0GORGE\0HANCHE\0INTESTIN\0"
    "LARYNX\0MOLLET\0MUSCLE\0NUQUE\0OMOPLATE\0ORTEIL\0"
    "PANCREAS\0POIGNET\0RETINE\0TENDON\0TIBIA\0VENTRE\0"
    "BULBE\0CARPE\0CRANE\0CRETE\0COLON\0GENOU\0"
    "HYMEN\0LYMPHE\0SACRUM\0SINUS\0TARSE\0TEMPE\0"
    "UVULE\0VALVE\0BICEPS\0RADIUS\0SALIVE\0THYMUS\0"
    "AMYGDALE\0BRONCHE\0DIAPHRAGME\0EPIGLOTTE\0FOLLICULE\0GENCIVE\0"
    "HALLUX\0OVAIRE\0PHALANGE\0PLAQUETTE\0PUPILLE\0SCAPULA\0"
    "SPHINCTER\0SYNOVIE\0TESTICULE\0THORAX\0TRICEPS\0VISCERE\0"
    "ZYGOMATIQUE\0MEDIASTIN\0POUMON\0METATARSE\0FEMUR\0CORNE\0"
    "AGRONOME\0AMBASSADEUR\0ANIMATEUR\0APICULTEUR\0ATHLETE\0BIJOUTIER\0"
    "BOTANISTE\0BRASSEUR\0CHIRURGIEN\0DIPLOMATE\0ELECTRICIEN\0GEOLOGUE\0"
    "INGENIEUR\0JOURNALISTE\0LIBRAIRE\0MAGISTRAT\0NAVIGATEUR\0NOTAIRE\0"
    "PHARMACIEN\0POMPIER\0SCULPTEUR\0MAIRE\0AUTEUR\0SOLDAT\0"
    "ANALYSTE\0ARBITRE\0ARTISAN\0AUDITEUR\0BANQUIER\0CINEASTE\0"
    "DENTISTE\0EPICIER\0FACTEUR\0FERMIER\0FORGERON\0GEOMETRE\0"
    "GREFFIER\0JURISTE\0MEDECIN\0MUSICIEN\0OUVRIER\0PECHEUR\0"
    "RECTEUR\0NEGOCIANT\0MILITAIRE\0COMPTABLE\0MENUISIER\0PHILOSOPHE\0"
    "PHYSICIEN\0POLICIER\0PROFESSEUR\0REDACTEUR\0SOCIOLOGUE\0CHARPENTIER\0"
    "DESSINATEUR\0INSTITUTEUR\0INFORMATICIEN\0SUPERVISEUR\0BOUCHER\0ECONOMISTE\0"
    "SECRETAIRE\0AVION\0BARQUE\0BERLINE\0BICYCLETTE\0BULLDOZER\0"
    "CAMION\0CARAVANE\0COCKPIT\0CONVOI\0DIRIGEABLE\0FERRY\0"
    "FREGATE\0GONDOLE\0HELICE\0LOCOMOTIVE\0MOTEUR\0NAVETTE\0"
    "NAVIRE\0PAQUEBOT\0TRAMWAY\0VAISSEAU\0WAGON\0PHARE\0"
    "BIKINI\0BLOUSE\0BONNET\0BRACELET\0CASQUE\0CEINTURE\0"
    "CHAUSSURE\0CHEMISE\0COLLIER\0CORSET\0CRAVATE\0DIADEME\0"
    "ECHARPE\0ESPADRILLE\0IMPERMEABLE\0JAQUETTE\0JUPON\0KIMONO\0"
    "MANTEAU\0PARKA\0PENDENTIF\0PEIGNOIR\0SMOKING\0TUNIQUE\0"
    "TURBAN\0UNIFORME\0VESTE\0BERET\0GILET\0GANTS\0"
    "BLOUSON\0BOLERO\0CHAPEAU\0FOULARD\0MOUCHOIR\0PANTALON\0"
    "PELISSE\0SALOPETTE\0SOUTANE\0PARDESSUS\0TRICOT\0BOTTINE\0"
    "ARMOIRE\0BALCON\0BIBLIOTHEQUE\0BUFFET\0BUREAU\0CANAPE\0"
    "COUSSIN\0DOUCHE\0FAUTEUIL\0FENETRE\0GRENIER\0LAVABO\0"
    "LUSTRE\0MEUBLE\0PARQUET\0PENDULE\0PERRON\0PLACARD\0"
    "PLAFOND\0TERRASSE\0TIROIR\0TOITURE\0VASQUE\0ARCHE\0"
    "DALLE\0DECOR\0PAROI\0SEUIL\0VOUTE\0ARCADE\0"
    "AUVENT\0FACADE\0PILIER\0PORCHE\0COULOIR\0LAMBRIS\0"
    "LINTEAU\0PERGOLA\0VERANDA\0VESTIBULE\0CHARPENTE\0FRONTON\0"
    "PILASTRE\0PORTIQUE\0TREILLIS\0BALDAQUIN\0BOISERIE\0ESCALIER\0"
    "RIDEAU\0ROBINET\0PORTAIL\0BAROQUE\0BERCEUSE\0BLUES\0"
    "CANTATE\0CAPRICE\0FLUTE\0FUGUE\0GAMME\0GOSPEL\0"
    "GUITARE\0HARMONIE\0HAUTBOIS\0HYMNE\0MANDOLINE\0MAZURKA\0"
    "ORCHESTRE\0PIZZICATO\0POLKA\0REGGAE\0REFRAIN\0RHAPSODIE\0"
    "SONATE\0SYMPHONIE\0TANGO\0TEMPO\0TENOR\0TROMBONE\0"
    "TROMPETTE\0VALSE\0VIOLON\0VIOLONCELLE\0BASSE\0BATON\0"
    "CORDE\0FORTE\0RYTHME\0OCTAVE\0ACCORD\0ARPEGE\0"
    "MESURE\0TIMBRE\0HARMONICA\0INTERLUDE\0METRONOME\0SOLFEGE\0"
    "STACCATO\0TONALITE\0TREMOLO\0UNISSON\0VIBRATO\0DISSONANCE\0"
    "PIANOFORTE\0RITARDANDO\0CADENCE\0DIAPASON\0FINIR\0JETER\0"
    "JUGER\0LAVER\0POSER\0PUNIR\0SUBIR\0VENIR\0"
    "VISER\0VOLER\0ADORER\0ANIMER\0BRISER\0CACHER\0"
    "CALMER\0COLLER\0COUPER\0COURIR\0DORMIR\0DURCIR\0"
    "ENTRER\0EXIGER\0FERMER\0FONDER\0FORMER\0GARDER\0"
    "LANCER\0LIVRER\0MENTIR\0MONTER\0MOURIR\0NOMMER\0"
    "OPERER\0OUVRIR\0PARLER\0PARTIR\0PASSER\0PERDRE\0"
    "REAGIR\0RELIER\0RESTER\0ROMPRE\0ROUGIR\0SAUVER\0"
    "SENTIR\0SERVIR\0SIGNER\0TESTER\0VENDRE\0DANSER\0"
    "ACCEDER\0AFFICHER\0AGACER\0ATTERRIR\0CASSER\0CITER\0"
    "CLOUER\0DEMOLIR\0DOUBLER\0FIXER\0FLATTER\0FLEURIR\0"
    "FRAPPER\0FREINER\0FROTTER\0GOUVERNER\0GRAVIR\0GUIDER\0"
    "HABILLER\0HONORER\0INCLINER\0INTEGRER\0INVOQUER\0ISOLER\0"
    "LIMITER\0NAVIGUER\0NEGOCIER\0OSCILLER\0PESER\0RAMENER\0"
    "RELANCER\0RENVERSER\0SOULAGER\0UNIFIER\0DETRUIRE\0DEPOSER\0"
    "DEMANDER\0DISPOSER\0ABORDER\0ACCUSER\0ACHETER\0ADAPTER\0"
    "ADOPTER\0AJOUTER\0ALERTER\0ALLUMER\0APPELER\0APPUYER\0"
    "ARRETER\0ARROSER\0ASSUMER\0AVANCER\0BALAYER\0BLESSER\0"
    "CHANTER\0CHASSER\0CHOISIR\0COINCER\0CONFIER\0COUCHER\0"
    "COUVRIR\0CREUSER\0DRESSER\0ENVAHIR\0ENVOYER\0ETABLIR\0"
    "EVALUER\0FILTRER\0GLISSER\0GRANDIR\0GROSSIR\0HABITER\0"
    "IGNORER\0INCLURE\0INVITER\0MERITER\0NOURRIR\0OBTENIR\0"
    "OUBLIER\0PLANTER\0REDUIRE\0REFUSER\0REMPLIR\0REPARER\0"
    "REPETER\0RETIRER\0REUSSIR\0REVENIR\0RISQUER\0SOIGNER\0"
    "TOUCHER\0TROUVER\0VALIDER\0VAINCRE\0DOMINER\0PLONGER\0"
    "AFFIRMER\0AGRANDIR\0ANALYSER\0ASSISTER\0ATTACHER\0ATTRAPER\0"
    "CHERCHER\0CONSOLER\0CORRIGER\0CRAINDRE\0CUISINER\0DECEVOIR\0"
    "DEFENDRE\0DESSINER\0DISCUTER\0ECHAPPER\0ECLAIRER\0EMBALLER\0"
    "EMPORTER\0IMAGINER\0INFORMER\0INVENTER\0MELANGER\0MODIFIER\0"
    "OBSERVER\0PARTAGER\0PREPARER\0PROPOSER\0PROTEGER\0REALISER\0"
    "RECEVOIR\0RESOUDRE\0SOUFFRIR\0UTILISER\0VERIFIER\0ESCALADER\0"
    "INSTALLER\0QUALIFIER\0REJOINDRE\0RESPECTER\0SUPPRIMER\0TRAVERSER\0"
    "DISTRIBUER\0EMPRUNTER\0ENSEIGNER\0DESCENDRE\0ORGANISER\0SURVEILLER\0"
    "OCCUPER\0SOURIRE\0DIRIGER\0GRIMPER\0PROFITER\0ENCHANTER\0"
    "BOIRE\0ANNULER\0FINANCER\0SEPARER\0DEVINER\0BAIGNER\0"
    "CRUEL\0JUSTE\0LARGE\0LEGER\0LIBRE\0LOYAL\0"
    "MINCE\0NOBLE\0SOBRE\0VASTE\0DENSE\0EXACT\0"
    "FERME\0HARDI\0MALIN\0AGILE\0BANAL\0DIGNE\0"
    "ANCIEN\0FAIBLE\0FIDELE\0FURTIF\0JALOUX\0JOYEUX\0"
    "RAPIDE\0SEREIN\0TIMIDE\0UNIQUE\0VIVANT\0ARDENT\0"
    "CONFUS\0ENORME\0FAMEUX\0FEROCE\0FRUGAL\0GLOBAL\0"
    "HABILE\0MAIGRE\0MINEUR\0MOROSE\0NEUTRE\0OBSCUR\0"
    "OUVERT\0PASSIF\0PESANT\0STABLE\0STRICT\0TENACE\0"
    "ACERBE\0DIRECT\0DOCILE\0INFINI\0AIMABLE\0BIZARRE\0"
    "CERTAIN\0COURANT\0CREATIF\0CURIEUX\0DELICAT\0DISCRET\0"
    "DISTANT\0ELEGANT\0EVIDENT\0EXTREME\0FERTILE\0FURIEUX\0"
    "HEUREUX\0IMMENSE\0INTENSE\0LIBERAL\0LUXUEUX\0MODESTE\0"
    "NATUREL\0NERVEUX\0NOTABLE\0PARFAIT\0PATIENT\0POSITIF\0"
    "PROFOND\0PRUDENT\0REACTIF\0REBELLE\0SANGUIN\0SERIEUX\0"
    "SINCERE\0STOIQUE\0TYPIQUE\0VIBRANT\0VIOLENT\0ABSURDE\0"
    "CANDIDE\0CIVIQUE\0CULTIVE\0POMPEUX\0PIQUANT\0VAILLANT\0"
    "EFFICACE\0ELOQUENT\0EXIGEANT\0FAMILIER\0FLATTEUR\0GRACIEUX\0"
    "IMMEDIAT\0INNOCENT\0INTUITIF\0LUMINEUX\0MULTIPLE\0OFFICIEL\0"
    "ORIGINAL\0PAISIBLE\0PARTISAN\0POETIQUE\0PRIMITIF\0PUISSANT\0"
    "RUSTIQUE\0SOLENNEL\0TERRIBLE\0TORTUEUX\0VERTUEUX\0COHERENT\0"
    "DELIBERE\0DILIGENT\0DOMINANT\0EPHEMERE\0IMPULSIF\0INSOLITE\0"
    "BRILLANT\0COMPLEXE\0SPIRITUEL\0COURAGEUX\0DIFFICILE\0DYNAMIQUE\0"
    "ENERGIQUE\0EXUBERANT\0IMPARTIAL\0INTREPIDE\0JUDICIEUX\0MERITOIRE\0"
    "MINUSCULE\0MINUTIEUX\0MISERABLE\0PASSIONNE\0PERILLEUX\0PERPETUEL\0"
    "PLAUSIBLE\0SCEPTIQUE\0SERVIABLE\0SUPERIEUR\0TROUBLANT\0UNIVERSEL\0"
    "VALEUREUX\0COMPETENT\0CONSCIENT\0DECORATIF\0PITOYABLE\0PROVOCANT\0"
    "FORMIDABLE\0MAGNIFIQUE\0MYSTERIEUX\0NONCHALANT\0TRANQUILLE\0CAPRICIEUX\0"
    "CONSEQUENT\0DETESTABLE\0IMPLACABLE\0TRIOMPHANT\0VULNERABLE\0CHARITABLE\0"
    "ROMANTIQUE\0SCRUPULEUX\0SILENCIEUX\0FLAMBOYANT\0BIENVEILLANT\0NARCISSIQUE\0"
    "ORGUEILLEUX\0PERSPICACE\0CONTEMPLATIF\0CONVAINCANT\0IRRESISTIBLE\0SATISFAISANT\0"
    "OPTIMISTE\0SENSIBLE\0INSOLENT\0INDULGENT\0GAILLARD\0IMPRECIS\0"
    "MEDIOCRE\0PROPICE\0SAGACE\0INSTABLE\0UTILE\0VERTU\0"
    "DESTIN\0FIERTE\0GLOIRE\0HUMEUR\0RAISON\0CHAGRIN\0"
    "COURAGE\0DIGNITE\0DOULEUR\0JUSTICE\0MIRACLE\0PENSEE\0"
    "PLAISIR\0RANCUNE\0SAGESSE\0SILENCE\0PROBITE\0VANITE\0"
    "VIGUEUR\0AUDACE\0ETERNITE\0ILLUSION\0PATIENCE\0SOUVENIR\0"
    "TRAHISON\0TRISTESSE\0VERITE\0AMBITION\0CONFIANCE\0ESPERANCE\0"
    "EXIGENCE\0FIDELITE\0FRANCHISE\0GRATITUDE\0INTEGRITE\0INTUITION\0"
    "MODESTIE\0NOSTALGIE\0PRUDENCE\0TENACITE\0DESESPOIR\0ELOQUENCE\0"
    "EMPATHIE\0EXCELLENCE\0TOLERANCE\0TRADITION\0LEGITIMITE\0MEDIOCRITE\0"
    "OBSTINATION\0OPTIMISME\0RESILIENCE\0TEMPERANCE\0PERSEVERANCE\0PERSPICACITE\0"
    "PERTINENCE\0PHILOSOPHIE\0SPIRITUALITE\0TRANSCENDANCE\0LIBERTE\0ESPOIR\0"
    "CREATIVITE\0POUVOIR\0ACROBATE\0ADJOINT\0AFFAIRE\0AFFRONT\0"
    "AGENCE\0AGONIE\0AIRELLE\0ALCOVE\0ALLIAGE\0ALLURE\0"
    "AMERTUME\0AMIDON\0AMPOULE\0ANGOISSE\0ANNONCE\0ARAIGNEE\0"
    "ARBRE\0ARDEUR\0ARENE\0ARGENT\0ARMURE\0ATOUT\0"
    "AUBAINE\0AUBERGE\0AVENIR\0AVERSE\0AVOINE\0BANLIEUE\0"
    "BARRAGE\0BAUME\0BERCEAU\0BOMBE\0BORDURE\0BOUCLIER\0"
    "BOURGEON\0BOUTIQUE\0BREBIS\0BROSSE\0CARGAISON\0CHALOUPE\0"
    "CHAMBRE\0COLONNE\0COUPURE\0CREVASSE\0ECUME\0EMBLEME\0"
    "ENCRE\0ENIGME\0EPOQUE\0EQUIPAGE\0EVEIL\0EXPLOIT\0"
    "FAILLE\0FERMOIR\0FLAMBEAU\0FONDATION\0GESTION\0GOUTTE\0"
    "GREVE\0IMMEUBLE\0IMPACT\0INDICE\0INFUSION\0IVRESSE\0"
    "LEGENDE\0LUEUR\0LUTIN\0MANCHE\0MANSARDE\0MARCHE\0"
    "MARGE\0MECENE\0MIROITEMENT\0NICHE\0OREILLER\0ORIGINE\0"
    "OUTRAGE\0PALMARES\0PASSERELLE\0PATRONAGE\0PISTE\0PORTEE\0"
    "PRECIPICE\0PREMIERE\0PRESTIGE\0PROPRIETE\0QUARTIER\0RANDONNEE\0"
    "RECOLTE\0REFUGE\0REGIME\0REMBLAI\0RONDEUR\0RUMEUR\0"
    "SENTIER\0SILLAGE\0SORTILEGE\0SOUPLESSE\0STATURE\0STRATEGE\0"
    "TAILLE\0TERRAIN\0VALEUR\0VEINE\0VITRINE\0ZEPHYR\0"
    "ZENITH\0BETON\0COTON\0CRAIE\0EBENE\0ETAIN\0"
    "FIBRE\0GYPSE\0IVOIRE\0LAINE\0LIEGE\0LIMON\0"
    "PERLE\0PLOMB\0SABLE\0SILEX\0TUILE\0VERRE\0"
    "ARGILE\0BITUME\0CARTON\0COBALT\0CUIVRE\0MARBRE\0"
    "BALANCE\0BOUGIE\0BRIQUET\0CADENAS\0COMPAS\0ENCLUME\0"
    "EPINGLE\0ETIQUETTE\0EVENTAIL\0FICELLE\0FILET\0HUBLOT\0"
    "JUMELLES\0LOUPE\0MACHINE\0MARTEAU\0NIVEAU\0PANIER\0"
    "PINCE\0RASOIR\0ROUAGE\0SANGLE\0SERRURE\0TAMIS\0"
    "TRUELLE\0PIRATE\0CORSAIRE\0FANTOME\0DRAGON\0LICORNE\0"
    "ORACLE\0ESPION\0BOITIER\0ETAPE\0SIRENE\0ACIER\0"
    "LACET\0ANALOGIE\0OBSTACLE\0INCENDIE\0SATIN\0RESSORT\0"
    ;

/* ===================================================================
   Variables globales
   =================================================================== */
static int      erreurs;
static char     mot[MOT_MAX + 1];
static char     devine[MOT_MAX];
static char     util[27];
static int      nb_util;
static unsigned rng = 0x5A3Cu;

static int  manche_courante;
static int  score_total;
static char hist_mot  [NB_MANCHES][MOT_MAX + 1];
static int  hist_err  [NB_MANCHES];
static int  hist_score[NB_MANCHES];
static int  hist_found[NB_MANCHES];

static HofEntry g_hof[HOF_SIZE];

/* ===================================================================
   Generateur pseudo-aleatoire XORshift 16 bits
   =================================================================== */
static unsigned rnd(void)
{
    rng ^= rng << 7;
    rng ^= rng >> 9;
    rng ^= rng << 8;
    return rng;
}

/* ===================================================================
   Helper bas niveau : emettre un caractere graphique a une position
   =================================================================== */
static void g_c(int row, int col, char ch)
{
    GOTO(row, col);
    GFX_ON(); putchar(ch); GFX_OFF();
}

/* ===================================================================
   Fonctions de construction de cadres
   cbox : ligne centree dans un cadre (col bc, largeur interieure bw)
   lbox : ligne gauche avec marge 2 chars de chaque cote
   hline: ligne horizontale de cadre (haut ou bas)
   =================================================================== */
static void cbox(int r, int bc, int bw, const char *txt)
{
    int l = 0, p, i;
    const char *t = txt;
    while (*t++) l++;
    p = (bw - l) / 2;
    g_c(r, bc, G_V);
    GOTO(r, bc + 1);
    for (i = 0; i < p; i++) putchar(' ');
    while (*txt) putchar(*txt++);
    for (i = 0; i < bw - p - l; i++) putchar(' ');
    g_c(r, bc + bw + 1, G_V);
}

static void lbox(int r, int bc, int bw, const char *txt)
{
    int l = 0, i;
    const char *t = txt;
    while (*t++) l++;
    g_c(r, bc, G_V);
    GOTO(r, bc + 3);
    while (*txt) putchar(*txt++);
    for (i = 0; i < bw - 2 - l; i++) putchar(' ');
    g_c(r, bc + bw + 1, G_V);
}

static void hline(int r, int bc, int bw, char cl, char cr)
{
    int i;
    GOTO(r, bc);
    GFX_ON(); putchar(cl);
    for (i = 0; i < bw; i++) putchar(G_H);
    putchar(cr); GFX_OFF();
}

/* ===================================================================
   Hall of Fame : lecture, ecriture, test top5, insertion
   =================================================================== */
static void hof_read(HofEntry hof[HOF_SIZE])
{
    FILE *f;
    int   i, j;
    for (i = 0; i < HOF_SIZE; i++) { hof[i].nom[0] = '\0'; hof[i].score = 0; }
    f = fopen(HOF_FILE, "rb");
    if (!f) return;
    for (i = 0; i < HOF_SIZE; i++) {
        int lo, hi;
        for (j = 0; j <= HOF_NAMELEN; j++) {
            int c = fgetc(f); if (c == EOF) { fclose(f); return; }
            hof[i].nom[j] = (char)c;
        }
        lo = fgetc(f); if (lo == EOF) { fclose(f); return; }
        hi = fgetc(f); if (hi == EOF) { fclose(f); return; }
        hof[i].score = (unsigned)lo | ((unsigned)hi << 8);
    }
    fclose(f);
}

static void hof_write(HofEntry hof[HOF_SIZE])
{
    FILE    *f;
    int      i, j;
    unsigned s;
    f = fopen(HOF_FILE, "wb");
    if (!f) return;
    for (i = 0; i < HOF_SIZE; i++) {
        for (j = 0; j <= HOF_NAMELEN; j++) fputc(hof[i].nom[j], f);
        s = hof[i].score;
        fputc(s & 0xFF, f);
        fputc(s >> 8,   f);
    }
    fclose(f);
}

static int hof_in_top5(HofEntry hof[HOF_SIZE], unsigned score)
{
    int i;
    for (i = 0; i < HOF_SIZE; i++)
        if (score > hof[i].score) return 1;
    return 0;
}

static void hof_insert(HofEntry hof[HOF_SIZE], const char *nom, unsigned score)
{
    int i, j;
    for (i = 0; i < HOF_SIZE; i++)
        if (score > hof[i].score) break;
    if (i == HOF_SIZE) return;
    for (j = HOF_SIZE - 1; j > i; j--) hof[j] = hof[j-1];
    for (j = 0; j < HOF_NAMELEN && nom[j]; j++) hof[i].nom[j] = nom[j];
    hof[i].nom[j] = '\0';
    hof[i].score = score;
}

/* ===================================================================
   Helpers panneau de jeu droit
   =================================================================== */
static void p_hline(int row, char cl, char cr)
{
    int i;
    GOTO(row, P_L); GFX_ON();
    putchar(cl);
    for (i = 0; i < P_W; i++) putchar(G_H);
    putchar(cr); GFX_OFF();
}

static void p_sides(int row)
{
    g_c(row, P_L, G_V);
    g_c(row, P_R, G_V);
}

static void p_clr(int row)
{
    int i; GOTO(row, P_L + 1);
    for (i = 0; i < P_W; i++) putchar(' ');
}

/* ===================================================================
   Calcul du score d'une manche
   =================================================================== */
static int calc_score(int nerr, int len)
{
    return ((MAX_ERR - nerr) * 900) / MAX_ERR + len * 10;
}

/* ===================================================================
   Potence
   =================================================================== */
static void potence_draw(void)
{
    int i, r;
    GOTO(G_BROW, G_PCOL); GFX_ON();
    putchar(G_TL);
    for (i = G_PCOL + 1; i < G_RCOL; i++) putchar(G_H);
    putchar(G_TR); GFX_OFF();
    for (r = G_BROW + 1; r < G_GROW; r++) g_c(r, G_PCOL, G_V);
    g_c(G_BROW + 1, G_RCOL, G_V);
    GOTO(G_GROW, G_BLC); GFX_ON();
    putchar(G_BL); putchar(G_H); putchar(G_BT);
    for (i = G_PCOL + 1; i < G_BRC; i++) putchar(G_H);
    putchar(G_BR); GFX_OFF();
}

/* ===================================================================
   Bonhomme (redessine a chaque erreur)
   =================================================================== */
static void bonhomme_draw(void)
{
    int r;
    for (r = G_BROW + 2; r <= G_BROW + 6; r++) {
        GOTO(r, G_RCOL - 2); fputs("     ", stdout);
    }
    if (erreurs >= 1) { GOTO(G_BROW+2, G_RCOL-1); fputs("(O)", stdout); }
    if (erreurs >= 2) { g_c(G_BROW+3, G_RCOL, G_V); g_c(G_BROW+4, G_RCOL, G_V); }
    if (erreurs >= 3) g_c(G_BROW+3, G_RCOL-1, G_DL);
    if (erreurs >= 4) g_c(G_BROW+3, G_RCOL+1, G_DR);
    if (erreurs >= 5) g_c(G_BROW+5, G_RCOL-1, G_DL);
    if (erreurs >= 6) g_c(G_BROW+5, G_RCOL+1, G_DR);
}

/* ===================================================================
   Cadre du panneau de jeu
   =================================================================== */
static void cadre_panel(void)
{
    int r;
    p_hline(PR_TOP,   G_TL, G_TR);
    p_hline(PR_WSEP,  G_LT, G_RT);
    p_hline(PR_LSEP,  G_LT, G_RT);
    p_hline(PR_LSEP2, G_LT, G_RT);
    p_hline(PR_ESEP,  G_LT, G_RT);
    p_hline(PR_BOT,   G_BL, G_BR);
    for (r = PR_TOP + 1; r < PR_BOT; r++) {
        if (r==PR_WSEP || r==PR_LSEP || r==PR_LSEP2 || r==PR_ESEP) continue;
        p_sides(r);
    }
}

/* ===================================================================
   Barre de titre (row 0, statique)
   =================================================================== */
static void titre_draw(void)
{
    const char *t =
        "     [[ SUPER PENDU V1.1 ]]        Zenith Z-89 / Heathkit H-89  |  CP/M 2.2     ";
    GOTO(0, 0); REV_ON();
    fputs(t, stdout);
    REV_OFF();
}

/* ===================================================================
   Helpers entiers - pas de printf/sprintf
   =================================================================== */

/* Unsigned int, droit-justifie dans un champ de w chars */
static void put_uint_w(unsigned int v, int w)
{
    char tmp[6];
    int  n = 0, i;
    if (v == 0) { tmp[n++] = '0'; }
    else { unsigned int t = v; while (t) { tmp[n++] = '0' + t % 10; t /= 10; } }
    for (i = n; i < w; i++) putchar(' ');
    for (i = n - 1; i >= 0; i--) putchar(tmp[i]);
}

/* Chaine gauche-justifiee, completee a la largeur w */
static void put_str_lj(const char *s, int w)
{
    int n = 0;
    while (*s) { putchar(*s++); n++; }
    while (n < w) { putchar(' '); n++; }
}

/* ===================================================================
   Barre statut dynamique (row 23)
   Gauche  : " Manche : X/5"
   Centre  : "Score : XXXX"
   Droite  : "[ESC] : Quitter "
   =================================================================== */
static void statut_draw(int manche, int score)
{
    char buf[81];
    char sc[6];
    int  i, n, rp, sn = 0;
    const char *rgt = "[ESC] : Quitter ";
    const int   rl  = 16;

    for (i = 0; i < 80; i++) buf[i] = ' ';
    buf[80] = '\0';

    /* Left: " Manche : X/5" */
    n = 0;
    buf[n++]=' '; buf[n++]='M'; buf[n++]='a'; buf[n++]='n';
    buf[n++]='c'; buf[n++]='h'; buf[n++]='e'; buf[n++]=' ';
    buf[n++]=':'; buf[n++]=' ';
    buf[n++] = '0' + manche;
    buf[n++]='/'; buf[n++] = '0' + NB_MANCHES;

    /* Right */
    rp = 80 - rl;
    for (i = 0; i < rl; i++) buf[rp + i] = rgt[i];

    /* Centre: "Score : " (8) + score droit-justifie sur 4 = 12 chars, pos 34 */
    { int sv = score;
      if (sv <= 0) sc[sn++] = '0';
      else { int t = sv; while (t) { sc[sn++] = '0' + t % 10; t /= 10; } } }
    n = 34;
    buf[n++]='S'; buf[n++]='c'; buf[n++]='o'; buf[n++]='r';
    buf[n++]='e'; buf[n++]=' '; buf[n++]=':'; buf[n++]=' ';
    for (i = sn; i < 4; i++) buf[n++] = ' ';
    for (i = sn - 1; i >= 0; i--) buf[n++] = sc[i];

    GOTO(23, 0); REV_ON(); fputs(buf, stdout); REV_OFF();
}

/* ===================================================================
   Labels fixes du panneau de jeu
   =================================================================== */
static void labels_draw(void)
{
    p_clr(PR_WLBL); p_sides(PR_WLBL);
    GOTO(PR_WLBL, P_L + 2);
    REV_ON(); fputs(" MOT A DEVINER ", stdout); REV_OFF();
    p_clr(PR_LLBL); p_sides(PR_LLBL);
    GOTO(PR_LLBL, P_L + 2);
    REV_ON(); fputs(" LETTRES ESSAYEES ", stdout); REV_OFF();
}

/* ===================================================================
   Mot a deviner
   =================================================================== */
static void mot_draw(void)
{
    int  i, len, col, blen, bcol;
    { const char *p = mot; len = 0; while (*p++) len++; }
    p_clr(PR_WORD); p_sides(PR_WORD);
    p_clr(PR_WNFO); p_sides(PR_WNFO);
    col = P_L + 1 + (P_W - len * 2) / 2;
    if (col < P_L + 1) col = P_L + 1;
    GOTO(PR_WORD, col);
    for (i = 0; i < len; i++) {
        putchar(devine[i] ? mot[i] : '_');
        putchar(' ');
    }
    /* "( N lettre(s) )" : 2 + nb_chiffres + 9 ou 10 chars */
    blen = 2 + (len >= 10 ? 2 : 1) + (len > 1 ? 10 : 9);
    bcol = P_L + 1 + (P_W - blen) / 2;
    if (bcol < P_L + 1) bcol = P_L + 1;
    GOTO(PR_WNFO, bcol);
    fputs("( ", stdout);
    if (len >= 10) putchar('0' + len / 10);
    putchar('0' + len % 10);
    fputs(len > 1 ? " lettres )" : " lettre )", stdout);
}

/* ===================================================================
   Lettres essayees :
   Row PR_LTR1 : bonnes lettres (dans le mot)   en reverse video
   Row PR_LTR2 : mauvaises lettres (hors du mot) en texte normal
   =================================================================== */
static void util_draw(void)
{
    int i, j, in, gi, bi;
    p_clr(PR_LTR1); p_sides(PR_LTR1);
    p_clr(PR_LTR2); p_sides(PR_LTR2);
    gi = 0;
    bi = 0;
    for (i = 0; i < nb_util; i++) {
        in = 0;
        for (j = 0; mot[j]; j++)
            if (mot[j] == util[i]) { in = 1; break; }
        if (in) {
            GOTO(PR_LTR1, P_L + 2 + gi * 4);
            REV_ON(); putchar(util[i]); REV_OFF();
            gi++;
        } else {
            GOTO(PR_LTR2, P_L + 2 + bi * 4);
            putchar(util[i]);
            bi++;
        }
    }
}

/* ===================================================================
   Barre d'erreurs  [ X X . . . . ]  N / MAX
   =================================================================== */
static void etat_draw(void)
{
    int i;
    p_clr(PR_ERR); p_sides(PR_ERR);
    GOTO(PR_ERR, P_L + 2);
    fputs("Erreurs : [", stdout);
    for (i = 0; i < erreurs;    i++) fputs(" X", stdout);
    for (i = erreurs; i < MAX_ERR; i++) fputs(" .", stdout);
    fputs(" ]  ", stdout); putchar('0' + erreurs);
    fputs(" / ", stdout); putchar('0' + MAX_ERR);
}

/* ===================================================================
   Zone messages (rows ROW_MSG et ROW_MSG+1)
   =================================================================== */
static void msg_set(const char *s)
{
    GOTO(ROW_MSG,     2); CLREOL();
    GOTO(ROW_MSG + 1, 2); CLREOL();
    if (s && *s) { GOTO(ROW_MSG, 4); fputs(s, stdout); }
}

/* ===================================================================
   Invite de saisie (row ROW_INPUT)
   =================================================================== */
static void invite_draw(void)
{
    GOTO(ROW_INPUT, 2); CLREOL();
    GFX_ON(); putchar('h'); GFX_OFF();
    fputs(" Votre lettre : ", stdout);
    CUR_ON();
}

/* ===================================================================
   Test de victoire
   =================================================================== */
static int a_gagne(void)
{
    int i;
    for (i = 0; mot[i]; i++)
        if (!devine[i]) return 0;
    return 1;
}

/* ===================================================================
   Initialisation d'une manche
   =================================================================== */
static void partie_init(void)
{
    int idx, i, len;
    const char *p = MOTS_DATA;
    idx = rnd() % NB_MOTS;
    /* Skip idx words in flat array */
    for (i = 0; i < idx; i++) { while (*p) p++; p++; }
    /* Copy word into mot[] */
    for (len = 0; len < MOT_MAX && p[len]; len++) mot[len] = p[len];
    mot[len] = '\0';
    for (i = 0; i < len; i++) devine[i] = 0;
    for (i = 0; i < 27;  i++) util[i]   = '\0';
    nb_util = 0;
    erreurs = 0;
}

/* ===================================================================
   Ecran de jeu complet
   =================================================================== */
static void ecran_jeu(void)
{
    int i;
    CLS(); CUR_OFF();
    titre_draw();
    GOTO(ROW_SHADE, 0); GFX_ON();
    for (i = 0; i < 80; i++) putchar(G_SH);
    GFX_OFF();
    potence_draw();
    bonhomme_draw();
    cadre_panel();
    labels_draw();
    mot_draw();
    util_draw();
    etat_draw();
    statut_draw(manche_courante + 1, score_total);
}

/* ===================================================================
   Ecran de bienvenue
   Cadre : col 13..65 (BV_BW=51 int.), rows 2..20 (19 lignes)
   Centrage : (80-53)/2=13  (24-19)/2=2
   Textes lbox max 47 chars => marge 2 chars de chaque cote garantie
   =================================================================== */
#define BV_BC  13
#define BV_BW  51
#define BV_BR   2

static void ecran_bienvenue(void)
{
    CLS(); CUR_OFF();

    hline(BV_BR,    BV_BC, BV_BW, G_TL, G_TR);
    cbox(BV_BR+ 1,  BV_BC, BV_BW, "");
    cbox(BV_BR+ 2,  BV_BC, BV_BW, "* *   SUPER PENDU   * *");
    cbox(BV_BR+ 3,  BV_BC, BV_BW, "Par Claude I.A. & RomaX ManiaX pour");
    cbox(BV_BR+ 4,  BV_BC, BV_BW, "Zenith Z-89  /  Heathkit H-89");
    cbox(BV_BR+ 5,  BV_BC, BV_BW, "");
    lbox(BV_BR+ 6,  BV_BC, BV_BW, "Regles du jeu :");
    lbox(BV_BR+ 7,  BV_BC, BV_BW, "Devinez le mot secret lettre par lettre.");
    lbox(BV_BR+ 8,  BV_BC, BV_BW, "Chaque mauvaise lettre fait avancer le pendu.");
    lbox(BV_BR+ 9,  BV_BC, BV_BW, "6 erreurs = la manche est perdue (mot revele).");
    cbox(BV_BR+10,  BV_BC, BV_BW, "");
    lbox(BV_BR+11,  BV_BC, BV_BW, "Score (mot trouve uniquement) :");
    lbox(BV_BR+12,  BV_BC, BV_BW, "Moins d'erreurs = score plus eleve.");
    lbox(BV_BR+13,  BV_BC, BV_BW, "Les mots longs donnent un bonus de points.");
    lbox(BV_BR+14,  BV_BC, BV_BW, "Maximum : 1020 pts/manche, 5100 pour 5 manches.");
    cbox(BV_BR+15,  BV_BC, BV_BW, "");
    cbox(BV_BR+16,  BV_BC, BV_BW, "Barre d'espace pour commencer la partie");
    cbox(BV_BR+17,  BV_BC, BV_BW, "");
    hline(BV_BR+18, BV_BC, BV_BW, G_BL, G_BR);

    while (1) {
        int ch;
        rng++;
        ch = bdos(6, 0xFF);
        if (ch == ' ') break;
        if (ch != 0) putchar('\007');
    }
}

/* ===================================================================
   Ecran de resultats (apres les 5 manches)
   Cadre : col 1..78 (RS_BW=76 int.), rows 2..14
   Colonnes tableau : No=col4, Mot=col9, Err=col28, Score=col35
   =================================================================== */
#define RS_BC        1
#define RS_BW       76
#define RS_SCORE_COL 35

static void ecran_resultats(void)
{
    char nom[HOF_NAMELEN + 1];
    int  i, top5;

    CLS(); CUR_OFF();
    titre_draw();

    hline(2,  RS_BC, RS_BW, G_TL, G_TR);
    cbox(3,   RS_BC, RS_BW, "RESULTATS DE LA PARTIE  -  SUPER PENDU");
    hline(4,  RS_BC, RS_BW, G_LT, G_RT);
    g_c(5, RS_BC, G_V); g_c(5, RS_BC + RS_BW + 1, G_V);
    GOTO(5, RS_BC + 3);
    fputs("No   MOT                ERR    SCORE", stdout);
    hline(6,  RS_BC, RS_BW, G_LT, G_RT);

    for (i = 0; i < NB_MANCHES; i++) {
        g_c(7+i, RS_BC, G_V); g_c(7+i, RS_BC + RS_BW + 1, G_V);
        GOTO(7+i, RS_BC + 3);
        putchar('0' + i + 1); fputs("    ", stdout);
        put_str_lj(hist_mot[i], 15);
        fputs("    ", stdout);
        if (hist_found[i]) {
            putchar('0' + hist_err[i]); fputs("      ", stdout);
            put_uint_w((unsigned)hist_score[i], 4);
        } else {
            fputs("-      RATE", stdout);
        }
    }

    hline(12, RS_BC, RS_BW, G_LT, G_RT);
    g_c(13, RS_BC, G_V); g_c(13, RS_BC + RS_BW + 1, G_V);
    GOTO(13, RS_BC + 3); fputs("TOTAL", stdout);
    GOTO(13, RS_SCORE_COL); put_uint_w((unsigned)score_total, 4);
    hline(14, RS_BC, RS_BW, G_BL, G_BR);

    top5 = hof_in_top5(g_hof, (unsigned)score_total);

    if (top5) {
        GOTO(16, 10); REV_ON();
        fputs("  Nouveau record ! Score : ", stdout);
        put_uint_w((unsigned)score_total, 4);
        fputs("  ", stdout);
        REV_OFF();
        GOTO(18, 10);
        fputs("ENTREZ VOTRE NOM : ", stdout);
        CUR_ON();
        {
            int k = 0, raw;
            char ch;
            nom[0] = '\0';
            while (1) {
                raw = read_noecho();
                if (raw == 0x0D) { if (k > 0) break; }
                if ((raw == 0x08 || raw == 0x7F) && k > 0) {
                    k--;
                    nom[k] = '\0';
                    putchar(0x08); putchar(' '); putchar(0x08);
                } else if (k < HOF_NAMELEN && raw >= 0x20 && raw < 0x7F) {
                    ch = (char)raw;
                    nom[k++] = ch;
                    nom[k] = '\0';
                    putchar(ch);
                }
            }
        }
        CUR_OFF();
        hof_insert(g_hof, nom, (unsigned)score_total);
        hof_write(g_hof);
    } else {
        GOTO(17, (80 - 29) / 2);
        fputs("Barre d'espace pour continuer", stdout);
        CUR_OFF();
        { int _ch; while ((_ch = read_noecho()) != ' ') putchar('\007'); }
    }
}

/* ===================================================================
   Ecran d'au revoir + Hall of Fame
   Cadre merci : col 14..65 (AV_BW=50 int.), rows 2..9
   Hall of Fame : centre sur 80 cols, rows 11..19
     HOF_C=25 : col debut numero
     HOF_N=29 : col debut nom
     HOF_S=50 : col debut score
   =================================================================== */
#define AV_BC  14
#define AV_BW  50
#define AV_BR   2
#define HOF_C  25
#define HOF_N  29
#define HOF_S  50

static void ecran_au_revoir(void)
{
    int k, i;
    CLS(); CUR_OFF();

    hline(AV_BR,    AV_BC, AV_BW, G_TL, G_TR);
    cbox(AV_BR+ 1,  AV_BC, AV_BW, "");
    cbox(AV_BR+ 2,  AV_BC, AV_BW, "Au revoir !");
    cbox(AV_BR+ 3,  AV_BC, AV_BW, "");
    cbox(AV_BR+ 4,  AV_BC, AV_BW, "Merci d'avoir joue au Super Pendu.");
    cbox(AV_BR+ 5,  AV_BC, AV_BW, "A bientot j'espere pour une autre partie.");
    cbox(AV_BR+ 6,  AV_BC, AV_BW, "");
    hline(AV_BR+ 7, AV_BC, AV_BW, G_BL, G_BR);

    {
        const char *htitle = "*** HALL OF FAME - TOP 5 ***";
        GOTO(11, (80 - 28) / 2 - 1);
        REV_ON(); putchar(' '); fputs(htitle, stdout); putchar(' '); REV_OFF();
    }

    GOTO(12, 0); CLREOL();

    GOTO(13, HOF_C); fputs("No", stdout);
    GOTO(13, HOF_N); fputs("NOM", stdout);
    GOTO(13, HOF_S); fputs("SCORE", stdout);

    GOTO(14, HOF_C);
    for (k = 0; k < (HOF_S - HOF_C + 5); k++) putchar('-');

    for (i = 0; i < HOF_SIZE; i++) {
        GOTO(15 + i, HOF_C);
        putchar('0' + i + 1); putchar('.');
        if (g_hof[i].nom[0] != '\0') {
            GOTO(15 + i, HOF_N); put_str_lj(g_hof[i].nom, 16);
            GOTO(15 + i, HOF_S); put_uint_w(g_hof[i].score, 5);
        } else {
            fputs("  ---", stdout);
        }
    }

    CUR_ON();
}

/* ===================================================================
   Programme principal
   =================================================================== */
int main(void)
{
    int  c;
    int  i, j, found, sc_manche;

    for (i = 0; i < 3; i++) rnd();
    hof_read(g_hof);

    ecran_bienvenue();

    score_total = 0;
    for (manche_courante = 0;
         manche_courante < NB_MANCHES;
         manche_courante++) {

        partie_init();
        ecran_jeu();

        /* --- Boucle de jeu ---
         * A..Z     : afficher lettre a INV_COL (efface message si present)
         * ENTREE   : valider ; si deja essayee -> message, recommencer
         * BACKSPACE: effacer la lettre (sans toucher au message)
         * '\x1B'  : quitter
         * autre    : bip
         */
        while (!a_gagne() && erreurs < MAX_ERR) {

            c = 0;
            {
                int msg_on = 0;
                GOTO(ROW_MSG, 2); CLREOL();
                GOTO(ROW_MSG + 1, 2); CLREOL();
                invite_draw();

                while (1) {
                    int raw = read_noecho();
                    if (raw == 0x1B) goto fin;

                    if (c == 0) {
                        int up = (raw >= 'a' && raw <= 'z') ? raw - 32 : raw;
                        if (up >= 'A' && up <= 'Z') {
                            if (msg_on) {
                                GOTO(ROW_MSG + 1, 2); CLREOL();
                                msg_on = 0;
                            }
                            c = up;
                            GOTO(ROW_INPUT, INV_COL);
                            putchar(c); CUR_ON();
                        } else {
                            putchar('\007');
                        }
                    } else {
                        if (raw == 0x0D) {
                            found = 0;
                            for (i = 0; i < nb_util; i++)
                                if (util[i] == c) { found = 1; break; }
                            if (found) {
                                GOTO(ROW_MSG + 1, 4);
                                fputs("!! Lettre deja essayee, choisissez-en une autre !", stdout);
                                msg_on = 1;
                                GOTO(ROW_INPUT, INV_COL);
                                putchar(' ');
                                GOTO(ROW_INPUT, INV_COL);
                                CUR_ON();
                                c = 0;
                            } else {
                                break;
                            }
                        } else if (raw == 0x08 || raw == 0x7F) {
                            GOTO(ROW_INPUT, INV_COL);
                            putchar(' ');
                            GOTO(ROW_INPUT, INV_COL);
                            CUR_ON();
                            c = 0;
                        } else {
                            putchar('\007');
                        }
                    }
                }
                CUR_OFF();
            }

            msg_set("");
            util[nb_util++] = c;
            rng += c;

            found = 0;
            for (j = 0; mot[j]; j++)
                if (mot[j] == c) { devine[j] = 1; found = 1; }
            if (!found) erreurs++;

            bonhomme_draw();
            mot_draw();
            util_draw();
            etat_draw();
            statut_draw(manche_courante + 1, score_total);
        }

        /* --- Fin de manche --- */
        hist_found[manche_courante] = a_gagne();
        hist_err  [manche_courante] = erreurs;
        { int k; for (k = 0; k < MOT_MAX && mot[k]; k++) hist_mot[manche_courante][k] = mot[k];
          hist_mot[manche_courante][k] = '\0'; }

        { int mlen = 0; const char *p = mot; while (*p++) mlen++;
          sc_manche = hist_found[manche_courante] ?
                      calc_score(erreurs, mlen) : 0; }
        hist_score[manche_courante] = sc_manche;
        score_total += sc_manche;

        statut_draw(manche_courante + 1, score_total);

        if (!hist_found[manche_courante]) {
            for (i = 0; mot[i]; i++) devine[i] = 1;
            mot_draw();
        }

        if (manche_courante < NB_MANCHES - 1) {
            GOTO(ROW_MSG,     2); CLREOL();
            GOTO(ROW_MSG + 1, 2); CLREOL();
            GOTO(ROW_MSG + 1, (80 - 53) / 2);
            fputs("Appuyer sur la barre d'espace pour la manche suivante", stdout);
            CUR_OFF();
            { int _ch; while ((_ch = read_noecho()) != ' ') putchar('\007'); }
        }
    }

    ecran_resultats();

fin:
    ecran_au_revoir();
    return 0;
}
