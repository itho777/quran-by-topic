/**
 * build_corpus_stopwords.js
 * ─────────────────────────────────────────────────────────────────────────────
 * Pre-computes the combined stop word list for the Quran search app.
 *
 * FINDINGS: search_index.json is already pre-filtered — extremely common
 * words (yang, dan, the, and, allah, etc.) are excluded at index build time.
 * Max word coverage in the index is ~500 verses (8% of 6236). Therefore,
 * corpus-derived filtering from the index catches no additional stop words
 * beyond what the NLP lists already cover.
 *
 * The strategy:
 *   - NLP List (ID): stopwords-iso/stopwords-id  — 258 peer-reviewed words
 *   - NLP List (EN): stopwords-iso/stopwords-en  — 575 peer-reviewed words
 *   - Quran UI meta: search-specific non-Islamic meta-words
 *   - Corpus layer:  reserved for future use if index is rebuilt without pre-filtering
 *
 * Re-run this script any time the search index is rebuilt:
 *   node scripts/build_corpus_stopwords.js
 *
 * Output: data/stop_words_corpus.json  (~5 KB, cached by service worker)
 * ─────────────────────────────────────────────────────────────────────────────
 */

const fs   = require('fs');
const path = require('path');

const INDEX_FILE  = path.join(__dirname, '..', 'data', 'search_index.json');
const OUTPUT_FILE = path.join(__dirname, '..', 'data', 'stop_words_corpus.json');

// ── Indonesian stop words (stopwords-iso/stopwords-id, 258 words) ────────────
const NLP_ID = [
  'ada','adalah','adanya','adapun','agak','agaknya','agar','akan','akankah',
  'akhir','akhiri','akhirnya','aku','akulah','amat','amatlah','anda','andalah',
  'antar','antara','antaranya','apa','apaan','apabila','apakah','apalagi',
  'apatah','artinya','asal','asalkan','atas','atau','ataukah','ataupun',
  'awal','awalnya','bagai','bagaikan','bagaimana','bagaimanakah','bagaimanapun',
  'bagi','bagian','bahkan','bahwa','bahwasanya','baik','bakal','bakalan',
  'balik','banyak','bapak','baru','bawah','beberapa','begini','beginian',
  'beginikah','beginilah','begitu','begitukah','begitulah','begitupun',
  'bekerja','belakang','belakangan','belum','belumlah','benar','benarkah',
  'benarlah','berada','berakhir','berakhirlah','berakhirnya','berapa',
  'berapakah','berapalah','berapapun','berarti','berawal','berbagai',
  'berdatangan','beri','berikan','berikut','berikutnya','berjumlah',
  'berkali-kali','berkata','berkehendak','berkeinginan','berkenaan',
  'berlainan','berlalu','berlangsung','berlebihan','bermacam','bermacam-macam',
  'bermaksud','bermula','bersama','bersama-sama','bersiap','bersiap-siap',
  'bertanya','bertanya-tanya','berturut','berturut-turut','bertutur','berujar',
  'berupa','besar','betul','betulkah','biasa','biasanya','bila','bilakah',
  'bisa','bisakah','boleh','bolehkah','bolehlah','buat','bukan','bukankah',
  'bukanlah','bukannya','bulan','bung','cara','caranya','cukup','cukupkah',
  'cukuplah','cuma','dahulu','dalam','dan','dapat','dari','daripada','datang',
  'dekat','demi','demikian','demikianlah','dengan','depan','di','dia',
  'diakhiri','diakhirinya','dialah','diantara','diantaranya','diberi',
  'diberikan','diberikannya','dibuat','dibuatnya','didapat','didatangkan',
  'digunakan','diibaratkan','diibaratkannya','diingat','diingatkan',
  'diinginkan','dijawab','dijelaskan','dijelaskannya','dikarenakan',
  'dikatakan','dikatakannya','dikerjakan','diketahui','diketahuinya','dikira',
  'dilakukan','dilalui','dilihat','dimaksud','dimaksudkan','dimaksudkannya',
  'dimaksudnya','diminta','dimintai','dimisalkan','dimulai','dimulailah',
  'dimulainya','dimungkinkan','dini','dipastikan','diperbuat','diperbuatnya',
  'dipergunakan','diperkirakan','diperlihatkan','diperlukan','diperlukannya',
  'dipersoalkan','dipertanyakan','dipunyai','diri','dirinya','disampaikan',
  'disebut','disebutkan','disebutkannya','disini','disinilah','ditambahkan',
  'ditandaskan','ditanya','ditanyai','ditanyakan','ditegaskan','ditujukan',
  'ditunjuk','ditunjuki','ditunjukkan','ditunjukkannya','ditunjuknya',
  'dituturkan','dituturkannya','diucapkan','diucapkannya','diungkapkan',
  'dong','dua','dulu','empat','enggak','enggaknya','entah','entahlah',
  'guna','gunakan','hal','hampir','hanya','hanyalah','hari','harus',
  'haruslah','harusnya','ia','ialah','ibaratkan','ibaratnya','ibu','ikut',
  'ingat','ingat-ingat','ingin','inginkan','ini','inilah','itu','itulah',
  'jadi','jadikan','jadinya','jangan','jangankan','janganlah','jauh','jawab',
  'jawaban','jawabnya','jelas','jelaskan','jelaslah','jelasnya','jika',
  'jikalau','juga','jumlah','jumlahnya','justru','kala','kalau','kalaulah',
  'kalaupun','kalian','kami','kamilah','kamu','kamulah','kapan',
  'kapankah','kapanpun','karena','karenanya','kasus','kata','katakan',
  'katakanlah','katanya','ke','keadaan','kebetulan','kebanyakan','keduanya',
  'keinginan','kelamaan','kembali','kemudian','kepada','kepadanya','kesamaan',
  'ketika','khususnya','kini','kiranya','kita','kitalah','kok','kurang',
  'lagi','lagian','lain','lainnya','lakukan','lalu','lama','langsung',
  'lebih','lewat','lima','luar','maka','makanya','makin','malah','malahan',
  'mampu','mampukah','mana','manakala','masing-masing','maupun','melainkan',
  'melakukan','melalui','melihat','memang','memberikan','membuat','memiliki',
  'memungkinkan','menaiki','mencari','mendapat','mendapatkan','mengenai',
  'menghendaki','menginginkan','mengira','mengucapkan','menjadi','merupakan',
  'meski','meskipun','minta','mohon','mu','mulai','mungkin','namun','nanti',
  'nantinya','nyatanya','oleh','pada','padahal','padanya','paling','pasti',
  'pastikan','pastinya','pernah','pertanyaan','pihak','pula','pun','rupanya',
  'saat','saatnya','saja','sama','sama-sama','sampai','sangat','sangatlah',
  'seandainya','sebab','sebabnya','sebagai','sebagaimana','sebagian',
  'sebelum','sebelumnya','sebenarnya','sedang','sedangkan','sedikit',
  'seharusnya','sejak','sekadar','sekarang','seketika','sekiranya','sekitar',
  'sela','selain','selalu','selama','seluruh','semua','seorang','seringkali',
  'seseorang','sesudah','setelah','setidaknya','siapa','siapakah','sudah',
  'sudahkah','sudahlah','supaya','tadi','tadinya','tak','tampak','tanpa',
  'tanya','tanyakan','tanyanya','tapi','tegas','tegaskan','telah','tentang',
  'tentu','tentunya','tepat','terdapat','terhadap','terjadinya','tersebut',
  'terutama','tetapi','tiap','tidak','tidakkah','tidaklah','toh','turut',
  'untuk','walaupun','yang'
];

// ── English stop words (stopwords-iso/stopwords-en, 575 words) ───────────────
const NLP_EN = [
  'a',"a's",'able','about','above','abroad','according','accordingly','across',
  'act','actually','adj','after','afterwards','again','against','ago','ah',
  'ahead',"ain't",'all','allow','allows','almost','alone','along','already',
  'also','although','always','am','amid','amidst','among','amongst','amount',
  'an','and','another','any','anybody','anyhow','anymore','anyone','anything',
  'anyway','anyways','anywhere','apart','apparently','appear','appreciate',
  'approximately','are',"aren't",'arise','around','as','aside','ask','asked',
  'asking','asks','associated','at','available','away','awfully',
  'back','backward','backwards','be','became','because','become','becomes',
  'becoming','been','before','beforehand','began','begin','beginning',
  'beginnings','begins','behind','being','beings','believe','below','beside',
  'besides','best','better','between','beyond','big','both','bottom','brief',
  'briefly','but','by',
  'call','came','can',"can't",'cannot','cant','case','cases','cause','causes',
  'certain','certainly','changes','clearly','cmon','come','comes','concerning',
  'consequently','consider','considering','contain','containing','contains',
  'could',"could've","couldn't",'couldnt','course','currently',
  'dare',"daren't",'date','dear','definitely','describe','described','despite',
  'did',"didn't",'didnt','differ','different','differently','directly',
  'do','does',"doesn't",'doesnt','doing',"don't",'done','dont','doubtful',
  'down','downed','downing','downs','downwards','due','during',
  'each','early','ed','effect','eight','eighty','either','eleven','else',
  'elsewhere','empty','end','ended','ending','ends','enough','entirely',
  'especially','even','evenly','ever','evermore','every','everybody',
  'everyone','everything','everywhere','exactly','except',
  'fairly','far','farther','felt','few','fewer','fifteen','fifth','fifty',
  'fill','find','finds','first','five','followed','following','follows',
  'for','forever','former','formerly','forth','forty','forward','found',
  'four','from','front','full','fully','further','furthermore',
  'gave','general','generally','get','gets','getting','give','given','gives',
  'giving','go','goes','going','gone','got','gotten','great','greater',
  'greatest','greetings',
  'had',"hadn't",'hadnt','half','happens','hardly','has',"hasn't",'hasnt',
  'have',"haven't",'havent','having','he',"he'd","he'll","he's",'hed',
  'hello','help','hence','her','here',"here's",'hereafter','hereby',
  'herein','hereupon','hers','herself','hes','hid','high','higher','highest',
  'him','himself','his','home','hopefully','how',"how'd","how'll","how's",
  'howbeit','however','hundred',
  'i',"i'd","i'll","i'm","i've",'if','ill','immediate','immediately',
  'importance','important','in','inasmuch','indeed','indicate','indicated',
  'indicates','information','inner','inside','insofar','instead','interest',
  'interested','interesting','interests','into','inward','is',"isn't",'isnt',
  'it',"it'd","it'll","it's",'itd','itll','its','itself','ive',
  'just','keep','keeps','kept','kind','knew','know','known','knows',
  'large','largely','last','lately','later','latest','latter','least',
  'less','lest','let',"let's",'like','likely','likewise','little','long',
  'longer','longest','look','looking','looks','low','lower','ltd',
  'made','mainly','make','makes','many','may','maybe','me','meanwhile',
  'member','members','might',"mightn't",'mine','minus','miss','more',
  'moreover','most','mostly','mr','mrs','much','must',"mustn't",'my',
  'myself','name','namely','nd','near','nearly','necessary','need','needs',
  'neither','never','nevertheless','new','next','nine','no','nobody','non',
  'none','nor','not','nothing','now','nowhere','obviously','of','off','often',
  'on','once','one','ones','only','onto','or','other','others','otherwise',
  'ought','our','ours','ourselves','out','outside','over','overall','own',
  'particular','particularly','per','perhaps','placed','please','plus',
  'possible','presumably','probably','provided',
  'quite','rather','really','reasonably','regarding','regardless','relatively',
  'respectively','right','round','same','say','says','second','secondly',
  'see','seeing','seem','seemed','seeming','seems','seen','self','selves',
  'sensibly','serious','seriously','seven','several','shall',"shan't",
  'she',"she'd","she'll","she's",'shed','should',"should've","shouldn't",
  'since','six','so','some','somebody','someday','somehow','something',
  'sometime','sometimes','somewhat','somewhere','soon','sorry','specified',
  'specify','specifying','still','sub','such','sup','sure',
  'take','taken','tell','tends','than','thank','thanks','that',"that's",
  'the','their','theirs','them','themselves','then','thence','there',
  "there's",'thereafter','thereby','therefore','therein','thereupon','these',
  'they',"they'd","they'll","they're","they've",'this','thorough',
  'thoroughly','those','though','through','throughout','thru','thus','to',
  'together','too','took','toward','towards','tried','tries','truly','try',
  'trying','twice',
  'under','unless','until','up','upon','us','use','used','uses','using',
  'usually','value','various','very','via','was',"wasn't",'we',"we'd",
  "we'll","we're","we've",'welcome','well','went','were',"weren't",'what',
  "what's",'whatever','when','whence','whenever','where',"where's",
  'whereafter','whereas','whereby','wherein','whereupon','wherever','whether',
  'which','while','who',"who's",'whoever','whom','whose','why','will',
  'willing','wish','with','within','without',"won't",'wonder','would',
  "would've","wouldn't",'you',"you'd","you'll","you're","you've",'your',
  'yours','yourself','yourselves'
];

// ── Quran search UI meta-words (not Islamic terms) ───────────────────────────
const META = [
  'verse','surah','quran','ayah','ayat','surat','contains','regarding',
  'find','show','search','cari','berisi','tampilkan','tunjukkan','carikan',
  'tentang','mengenai','bantu','tolong'
];

// ── Corpus-derived layer ─────────────────────────────────────────────────────
// Note: search_index.json is pre-filtered (max word coverage ~8% of verses).
// At the 10% threshold there are 0 corpus stop words, confirming the index
// builder already strips high-frequency tokens. The corpus layer is kept
// for forward-compatibility if the index is ever rebuilt without pre-filtering.
const CORPUS_THRESHOLD = 0.10;
let corpusWords = [];

if (fs.existsSync(INDEX_FILE)) {
  console.log('Scanning index for corpus stop words...');
  const index = JSON.parse(fs.readFileSync(INDEX_FILE, 'utf8'));
  const allWords = Object.keys(index);

  const allVerseKeys = new Set();
  for (const w of allWords) {
    index[w].split(',').forEach(p => allVerseKeys.add(p.split('_')[0]));
  }
  const totalVerses = allVerseKeys.size;
  const minCount = Math.floor(totalVerses * CORPUS_THRESHOLD);
  console.log(`  Verses: ${totalVerses}, threshold: >=${minCount} (${CORPUS_THRESHOLD*100}%)`);

  for (const word of allWords) {
    const vks = new Set(index[word].split(',').map(p => p.split('_')[0]));
    if (vks.size >= minCount) corpusWords.push(word);
  }
  console.log(`  Corpus stop words found: ${corpusWords.length}`);
}

// ── Merge all sources ────────────────────────────────────────────────────────
const merged = [...new Set([...NLP_ID, ...NLP_EN, ...META, ...corpusWords])].sort();

const output = {
  _meta: {
    generated:          new Date().toISOString(),
    nlp_id_count:       NLP_ID.length,
    nlp_en_count:       NLP_EN.length,
    meta_count:         META.length,
    corpus_count:       corpusWords.length,
    corpus_threshold:   CORPUS_THRESHOLD,
    total_unique:       merged.length,
    note: 'Re-run: node scripts/build_corpus_stopwords.js'
  },
  words: merged
};

fs.writeFileSync(OUTPUT_FILE, JSON.stringify(output), 'utf8');  // minified for small file size
console.log(`\n✅ Written ${merged.length} stop words → ${OUTPUT_FILE}`);
console.log(`   File size: ${(fs.statSync(OUTPUT_FILE).size / 1024).toFixed(1)} KB`);
