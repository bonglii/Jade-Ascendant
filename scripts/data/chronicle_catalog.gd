extends RefCounted
## Approved bilingual story. Access derives from existing clears; no retroactive rewards.
const ENTRIES: Array = [
  {
    "id": "verdant_arrival",
    "chapter": 1,
    "realm": "Verdant Qi Valley",
    "kind": "enter",
    "requires": null,
    "title": {
      "id": "Sumpah pertama",
      "en": "The first oath"
    },
    "body": {
      "id": "Di antara penanda tua Verdant Qi Valley, Lin Yue menemukan jejak sumpah yang terputus. Ia melangkah ke jalur ascension untuk mengetahui siapa yang pernah dijaga oleh para penjaga lembah.",
      "en": "Among the old markers of Verdant Qi Valley, Lin Yue finds traces of a broken oath. He enters the path of ascension to learn whom the valley guardians once protected."
    },
    "line": {
      "id": "Kalau gerbang ini masih berdiri, pasti ada seseorang yang menunggunya terbuka.",
      "en": "If this gate still stands, someone must be waiting for it to open."
    }
  },
  {
    "id": "verdant_clear",
    "chapter": 1,
    "realm": "Verdant Qi Valley",
    "kind": "clear",
    "requires": "1-5",
    "title": {
      "id": "Gerbang yang menjaga",
      "en": "The gate that shelters"
    },
    "body": {
      "id": "Di jantung lembah, Lin Yue membaca maksud penanda itu: gerbang dibuat untuk menjaga jalan pulang, bukan memilih siapa yang pantas pergi. Jejak sumpah berikutnya mengarah ke Crimson Moon Sect.",
      "en": "At the valley’s heart, Lin Yue learns the markers’ purpose: the gate protected a way home, rather than choosing who deserved to leave. The next trace leads to the Crimson Moon Sect."
    },
    "line": {
      "id": "Aku akan mencari ujung sumpah ini. Jalan pulang tidak boleh hilang.",
      "en": "I will follow this oath to its end. The way home must not be lost."
    }
  },
  {
    "id": "crimson_arrival",
    "chapter": 2,
    "realm": "Crimson Moon Sect",
    "kind": "enter",
    "requires": "1-5",
    "title": {
      "id": "Harga sebuah janji",
      "en": "The cost of a promise"
    },
    "body": {
      "id": "Crimson Moon Sect menyimpan ikrar para muridnya di balik segel merah. Lin Yue datang membawa jejak dari lembah. Di sini, setiap janji dicatat, tetapi tidak semua pengorbanan disebutkan.",
      "en": "The Crimson Moon Sect keeps its disciples’ vows behind crimson seals. Lin Yue arrives with the valley’s trace. Every promise is recorded here, but not every sacrifice is named."
    },
    "line": {
      "id": "Siapa yang menanggung janji ketika yang berjanji telah pergi?",
      "en": "Who carries a promise after its maker is gone?"
    }
  },
  {
    "id": "crimson_clear",
    "chapter": 2,
    "realm": "Crimson Moon Sect",
    "kind": "clear",
    "requires": "2-5",
    "title": {
      "id": "Nama yang disisihkan",
      "en": "The name left out"
    },
    "body": {
      "id": "Segel terakhir memperlihatkan sebuah nama yang sengaja dihapus dari daftar murid. Sumpah penjaga bukan gagal; seseorang memutus jalurnya. Lin Yue membawa salinan nama itu menuju Nine Heavens Star Palace.",
      "en": "The final seal reveals a name deliberately erased from the disciples’ roll. The guardians’ oath did not fail; someone severed its path. Lin Yue takes the name to Nine Heavens Star Palace."
    },
    "line": {
      "id": "Sebuah nama yang dihapus tetap pernah menjadi seseorang.",
      "en": "An erased name still belonged to someone."
    }
  },
  {
    "id": "stars_arrival",
    "chapter": 3,
    "realm": "Nine Heavens Star Palace",
    "kind": "enter",
    "requires": "2-5",
    "title": {
      "id": "Langit tanpa nama",
      "en": "A sky without names"
    },
    "body": {
      "id": "Di Nine Heavens Star Palace, rasi bintang mencatat para cultivator yang melampaui realm. Nama dari segel merah tidak ada di sana. Lin Yue mengikuti satu garis cahaya yang berakhir di ruang kosong.",
      "en": "At Nine Heavens Star Palace, constellations record cultivators who crossed the realms. The name from the crimson seal is absent. Lin Yue follows a line of light that ends in an empty space."
    },
    "line": {
      "id": "Mungkin yang hilang bukan bintangnya, tetapi orang yang mengingatnya.",
      "en": "Perhaps the star is not missing. Perhaps its witness is."
    }
  },
  {
    "id": "stars_clear",
    "chapter": 3,
    "realm": "Nine Heavens Star Palace",
    "kind": "clear",
    "requires": "3-5",
    "title": {
      "id": "Jalur yang diputus",
      "en": "The severed path"
    },
    "body": {
      "id": "Rasi terakhir mengungkap pilihan sang penjaga: memutus jalur qi agar retakan antar-realm tidak menelan desa di bawahnya. Jawaban lengkapnya tertahan di Frostveil Abyss, bersama ingatan yang tak pernah sampai pulang.",
      "en": "The final constellation reveals the guardian’s choice: sever the qi path before a rift consumed the villages below. The whole answer lies in Frostveil Abyss, with memories that never reached home."
    },
    "line": {
      "id": "Kekuatan yang berhenti pun bisa sedang melindungi.",
      "en": "Power that stops may still be protecting someone."
    }
  },
  {
    "id": "frost_arrival",
    "chapter": 4,
    "realm": "Frostveil Abyss",
    "kind": "enter",
    "requires": "3-5",
    "title": {
      "id": "Ingatan di bawah es",
      "en": "Memory beneath the ice"
    },
    "body": {
      "id": "Frostveil Abyss menyimpan gema pertempuran dalam es. Lin Yue mendengar dua suara pada sumpah yang sama: satu meminta ia bertahan, satu memintanya pulang. Tidak ada yang meminta ia menjadi yang terkuat.",
      "en": "Frostveil Abyss preserves echoes of battle in its ice. Lin Yue hears two voices within the same oath: one asks the guardian to endure, the other to return. Neither asks him to become the strongest."
    },
    "line": {
      "id": "Aku tidak datang untuk membekukan luka ini sekali lagi.",
      "en": "I did not come to freeze this wound again."
    }
  },
  {
    "id": "frost_clear",
    "chapter": 4,
    "realm": "Frostveil Abyss",
    "kind": "clear",
    "requires": "4-5",
    "title": {
      "id": "Yang harus dibawa pulang",
      "en": "What must return"
    },
    "body": {
      "id": "Ingatan itu kembali utuh: sumpah terputus bukan perintah untuk menunggu selamanya. Lin Yue membawa kesaksiannya menuju Solar Nirvana Domain, tempat jalur qi dapat ditempa ulang tanpa menghapus orang yang menjaganya.",
      "en": "The memory returns whole: the broken oath was never an order to wait forever. Lin Yue carries its testimony to Solar Nirvana Domain, where the qi path may be reforged without erasing its guardian."
    },
    "line": {
      "id": "Aku akan membawa kesaksiannya. Tidak seorang pun harus menunggu tanpa nama.",
      "en": "I will carry this testimony. No one should wait without a name."
    }
  },
  {
    "id": "solar_arrival",
    "chapter": 5,
    "realm": "Solar Nirvana Domain",
    "kind": "enter",
    "requires": "4-5",
    "title": {
      "id": "Sumpah dalam bara",
      "en": "An oath in the embers"
    },
    "body": {
      "id": "Di Solar Nirvana Domain, api menguji apa yang dibawa Lin Yue melintasi empat realm. Ia dapat mengejar puncak seorang diri. Namun kini ia tahu apa yang akan tertinggal jika jalan pulang kembali dikorbankan.",
      "en": "In Solar Nirvana Domain, fire tests what Lin Yue has carried across four realms. He could pursue the summit alone. Now he knows what would be left behind if the way home were sacrificed again."
    },
    "line": {
      "id": "Aku tidak akan menukar jalan pulang dengan sebuah takhta.",
      "en": "I will not trade the way home for a throne."
    }
  },
  {
    "id": "solar_clear",
    "chapter": 5,
    "realm": "Solar Nirvana Domain",
    "kind": "clear",
    "requires": "5-5",
    "title": {
      "id": "Sumpah yang kembali",
      "en": "The oath returns"
    },
    "body": {
      "id": "Lin Yue menempa ulang jalur yang terputus. Gerbang kembali terhubung, dan nama sang penjaga dikembalikan ke rasi. Ascension tidak mengakhiri perjalanannya; kini ada orang lain yang dapat menempuhnya dan tetap pulang.",
      "en": "Lin Yue reforges the severed path. The gates reconnect, and the guardian’s name returns to the stars. Ascension does not end his journey; now others can follow it and still return home."
    },
    "line": {
      "id": "Kalau aku bisa naik, jalan ini juga harus bisa membawa mereka pulang.",
      "en": "If I can ascend, this path must also bring them home."
    }
  },
  {
    "id": "verdant_oath_fragment",
    "chapter": 1,
    "realm": "Verdant Qi Valley",
    "kind": "optional",
    "requires": "optional:jade_oath_1_3_v1",
    "title": {
      "id": "Suara di batu giok",
      "en": "A voice in jade"
    },
    "body": {
      "id": "Sesudah ritual di Ruined Jade Shrine, satu kalimat menjadi terbaca: “Jaga jalan ini sampai mereka kembali.” Di bawahnya ada bekas nama yang belum dapat dipahami Lin Yue. Ia menyimpannya sebagai kesaksian, bukan perintah untuk tinggal.",
      "en": "After the ritual at Ruined Jade Shrine, one line becomes legible: “Keep this path until they return.” Beneath it lies a name Lin Yue cannot yet read. He keeps it as testimony, not a command to stay."
    },
    "line": {
      "id": "Sumpah ini punya tujuan. Aku akan mencari siapa yang belum pulang.",
      "en": "This oath had a purpose. I will find who has not returned."
    }
  },
{
  "id": "verdant_witness",
  "chapter": 1,
  "realm": "Verdant Qi Valley",
  "kind": "fragment",
  "requires": "1-3",
  "title": {
    "id": "Penanda yang diperbaiki",
    "en": "The mended marker"
  },
  "body": {
    "id": "Di tepi Bamboo Mist Pass, Lin Yue menegakkan penanda yang roboh. Seorang murid lembah mengaku pernah mengikuti cahayanya ketika kabut menutup jalan. Sumpah itu ternyata masih bekerja, jauh dari gerbang besar.",
    "en": "At the edge of Bamboo Mist Pass, Lin Yue raises a fallen marker. A valley disciple says its light once led him through the fog. The oath is still at work, far from the great gate."
  },
  "line": {
    "id": "Yang kecil pun bisa menjaga jalan pulang.",
    "en": "Even a small light can guard the way home."
  }
},
{
  "id": "crimson_witness",
  "chapter": 2,
  "realm": "Crimson Moon Sect",
  "kind": "fragment",
  "requires": "2-3",
  "title": {
    "id": "Satu nama di sisi gulungan",
    "en": "A name in the margin"
  },
  "body": {
    "id": "Di sisi gulungan merah, Lin Yue menemukan tulisan seorang penjaga dapur. Ia tidak tercatat sebagai cultivator, tetapi setiap malam menyiapkan bekal bagi murid yang menjaga segel. Lin Yue menyalin namanya bersama nama yang hilang.",
    "en": "In the margin of a crimson scroll, Lin Yue finds a kitchen keeper’s note. Never listed as a cultivator, she prepared food each night for the seal watch. Lin Yue copies her name beside the missing one."
  },
  "line": {
    "id": "Sumpah tidak hanya ditopang oleh pedang.",
    "en": "An oath is upheld by more than swords."
  }
},
{
  "id": "stars_witness",
  "chapter": 3,
  "realm": "Nine Heavens Star Palace",
  "kind": "fragment",
  "requires": "3-3",
  "title": {
    "id": "Rasi yang rendah",
    "en": "The low constellation"
  },
  "body": {
    "id": "Sebuah lensa tua mengarahkan cahaya istana ke desa di bawah. Murid-murid menyebutnya rasi yang rendah. Lin Yue memahami bahwa arah cahaya sama pentingnya dengan seberapa tinggi ia dapat mencapai langit.",
    "en": "An old lens directs the palace light toward a village below. The disciples call it the low constellation. Lin Yue learns that where light is sent matters as much as how high it rises."
  },
  "line": {
    "id": "Bintang yang menunduk tetaplah bintang.",
    "en": "A star looking down is still a star."
  }
},
{
  "id": "frost_witness",
  "chapter": 4,
  "realm": "Frostveil Abyss",
  "kind": "fragment",
  "requires": "4-3",
  "title": {
    "id": "Suara yang disimpan",
    "en": "The voice kept safe"
  },
  "body": {
    "id": "Di bawah es, Lin Yue mendengar pesan untuk seorang penjaga: pulanglah jika jalan sudah aman. Ia menyalin pesan itu sebelum memecahkan lapisan es di atasnya. Ingatan yang dijaga tidak harus terus terkurung.",
    "en": "Beneath the ice, Lin Yue hears a message to a guardian: return when the road is safe. He copies it before breaking the ice above. A memory kept safe need not remain imprisoned."
  },
  "line": {
    "id": "Mengingat bukan berarti menahan.",
    "en": "Remembering need not mean holding someone back."
  }
},
{
  "id": "solar_witness",
  "chapter": 5,
  "realm": "Solar Nirvana Domain",
  "kind": "fragment",
  "requires": "5-3",
  "title": {
    "id": "Api untuk menempa jalan",
    "en": "Fire to forge a road"
  },
  "body": {
    "id": "Di antara abu tungku, Lin Yue menemukan paku-paku giok yang belum selesai. Api domain ini pernah dipakai memperbaiki jembatan antar-realm. Ia membawa satu paku itu sebagai pengingat bahwa ascension juga dapat membangun jalan bagi orang lain.",
    "en": "Among the furnace ashes, Lin Yue finds unfinished jade rivets. The domain’s fire once repaired bridges between realms. He carries one rivet as a reminder that ascension can build a road for others."
  },
  "line": {
    "id": "Kekuatan ini harus membawa sesuatu pulang.",
    "en": "This strength must bring something home."
  }
}
]

static func unlocked(entry: Dictionary, cleared: Array, badges: Array) -> bool:
	if entry.id == "verdant_oath_fragment":
		return "keeper_of_the_oath" in badges
	return entry.get("requires") == null or str(entry.requires) in cleared
static func copy(entry: Dictionary, field: String, language: String) -> String:
	return str(entry.get(field,{}).get("id" if language == "id" else "en",""))
static func get_entry(id: String) -> Dictionary:
	for entry: Dictionary in ENTRIES:
		if entry.id == id:
			return entry.duplicate(true)
	return {}
static func for_chapter(chapter: int, kind: String) -> Dictionary:
	for entry: Dictionary in ENTRIES:
		if int(entry.chapter) == chapter and entry.kind == kind:
			return entry.duplicate(true)
	return {}
