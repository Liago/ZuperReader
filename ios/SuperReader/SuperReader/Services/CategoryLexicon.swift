import Foundation

// MARK: - Category Lexicon
//
// Signals used by `HeuristicCategoryClassifier`. Every entry is already
// normalized (lowercase, no diacritics). Keyword rules:
// - a trailing `*` marks a stem, matched as a word prefix
//   ("elezion*" → elezione/elezioni, "vaccin*" → vaccine/vaccino/vaccinazione);
// - entries with a space are phrases, matched on the whole normalized text;
// - anything else must match a whole word ("inter" ≠ "internet").

nonisolated enum CategoryLexicon {

    // MARK: Keywords (Italian + English)

    static let keywords: [ArticleCategory: [String]] = [
        .news: [
            "breaking", "cronaca", "incidente", "incidenti", "arrestat*", "arresto", "omicidi*", "polizia",
            "carabinieri", "indagin*", "procura", "tribunale", "processo", "sentenza", "terremoto", "alluvion*",
            "maltempo", "allerta", "sciopero", "police", "arrested", "murder", "shooting", "crash", "accident",
            "investigation", "court", "verdict", "earthquake", "flood", "floods", "storm", "strike",
            "ultime notizie", "latest news", "live updates", "aggiornamenti in diretta"
        ],
        .politics: [
            "governo", "parlament*", "senato", "camera dei deputati", "elezion*", "elettoral*", "partito",
            "partiti", "ministr*", "premier", "presidente del consiglio", "meloni", "schlein", "salvini",
            "mattarella", "decreto", "riforma", "referendum", "sindaco", "regionali", "europee", "opposizion*",
            "maggioranza", "coalizion*", "diplomazia", "ambasciat*", "guerra", "ucraina", "russia", "putin",
            "zelensky", "israele", "gaza", "hamas", "nato", "onu", "ue", "commissione europea", "bruxelles",
            "government", "parliament", "congress", "senate", "election", "elections", "electoral", "voters",
            "ballot", "democrat*", "republican*", "trump", "biden", "white house", "minister", "policy",
            "legislation", "lawmakers", "diplomac*", "sanction*", "ceasefire", "war", "united nations",
            "european union", "eu", "geopolitic*"
        ],
        .business: [
            "economia", "economic*", "economy", "mercat*", "borsa", "azioni", "titoli", "spread", "btp",
            "inflazion*", "inflation", "pil", "gdp", "recession*", "tassi", "interest rate", "interest rates",
            "bce", "ecb", "fed", "federal reserve", "banca", "banche", "bank", "banks", "banking", "finanz*",
            "financ*", "invest*", "fondi", "bilancio", "fatturato", "utili", "revenue", "profit*", "earnings",
            "trimestr*", "azienda", "aziende", "impresa", "imprese", "company", "companies", "startup",
            "startups", "venture capital", "ipo", "acquisizion*", "acquisition*", "merger*", "fusione", "ceo",
            "amministratore delegato", "lavoro", "occupazion*", "disoccupazion*", "salari*", "stipend*",
            "pensioni", "tasse", "fisco", "tax", "taxes", "dazi", "tariff*", "export", "industria",
            "industry", "retail", "consumi", "stocks", "shares", "nasdaq", "dow jones", "wall street",
            "piazza affari", "ftse", "mutuo", "mutui", "mortgage*", "risparmi*", "savings"
        ],
        .technology: [
            "tecnologi*", "technolog*", "tech", "software", "hardware", "app", "apps", "smartphone*", "iphone",
            "ipad", "android", "apple", "google", "microsoft", "amazon web services", "meta platforms", "openai",
            "anthropic", "nvidia", "samsung", "chip", "chips", "semiconduttor*", "semiconductor*", "processor*",
            "processore", "intelligenza artificiale", "artificial intelligence", "ai", "ia", "machine learning",
            "llm", "llms", "chatgpt", "gemini", "claude", "algoritm*", "algorithm*", "programmazione",
            "programming", "coding", "developer*", "sviluppator*", "javascript", "typescript", "python", "swift",
            "swiftui", "kotlin", "rust", "linux", "windows", "macos", "ios", "cloud", "server", "database",
            "api", "open source", "github", "cybersecurity", "sicurezza informatica", "hacker*", "malware",
            "ransomware", "data breach", "internet", "web", "browser", "gadget*", "wearable*", "robot*",
            "automazion*", "automation", "blockchain", "crypto", "bitcoin", "digital", "digitale", "computer",
            "laptop", "5g", "starlink", "elon musk"
        ],
        .science: [
            "scienz*", "scientif*", "science", "sciences", "scientist*", "ricerca", "ricercator*", "research",
            "researcher*", "studio pubblicato", "study published", "scoperta", "scoperto", "discovery",
            "discovered", "fisica", "physics", "quantum", "quantistic*", "particell*", "particle*", "cern",
            "biologia", "biology", "genetic*", "genetica", "genoma", "genome", "dna", "rna", "chimica",
            "chemistry", "molecol*", "molecul*", "evoluzion*", "evolution", "fossil*", "dinosaur*", "archeolog*",
            "spazio", "space", "nasa", "esa", "spacex", "razzo", "rocket*", "satellit*", "astronaut*",
            "astronom*", "telescop*", "pianet*", "planet*", "galass*", "galax*", "universo", "universe",
            "buco nero", "black hole", "marte", "mars", "luna", "moon", "matematic*", "mathemat*",
            "neuroscien*", "cervello", "brain", "laboratorio", "laboratory", "esperiment*", "experiment*",
            "peer review"
        ],
        .health: [
            "salute", "health", "medic*", "medicina", "medicine", "ospedal*", "hospital*", "pazient*",
            "patient*", "malatti*", "disease*", "tumor*", "tumour*", "cancro", "cancer", "oncolog*", "cardiac*",
            "cardiolog*", "diabet*", "alzheimer", "demenza", "dementia", "vaccin*", "virus", "covid",
            "influenza", "pandemi*", "epidemi*", "farmac*", "drug", "drugs", "terapi*", "therap*", "treatment*",
            "sintom*", "symptom*", "diagnos*", "nutrizion*", "nutrition*", "dieta", "diet", "obesit*", "sonno",
            "sleep", "salute mentale", "mental health", "ansia", "anxiety", "depression", "depressione",
            "psicolog*", "psycholog*", "benessere", "wellbeing", "wellness", "fitness", "allenament*", "workout*",
            "exercise", "oms", "sanita", "healthcare", "chirurg*", "surgery"
        ],
        .sports: [
            "sport", "sports", "calcio", "football", "soccer", "serie a", "champions league", "europa league",
            "premier league", "liga", "bundesliga", "mondiali", "world cup", "partita", "partite", "match",
            "gol", "goal", "allenator*", "coach", "squadra", "campionat*", "championship*", "classifica",
            "standings", "juventus", "juve", "inter", "atalanta", "fiorentina", "real madrid", "barcellona",
            "barcelona", "tennis", "sinner", "alcaraz", "djokovic", "wimbledon", "atp", "wta", "basket",
            "basketball", "nba", "eurolega", "volley", "pallavolo", "ciclismo", "cycling", "giro d italia",
            "tour de france", "formula 1", "f1", "motogp", "gran premio", "grand prix", "verstappen", "hamilton",
            "leclerc", "olimpiad*", "olympic*", "atleta", "atleti", "athlete*", "nfl", "rugby", "golf", "nuoto",
            "swimming", "sci", "ski", "maratona", "marathon", "calciomercato", "scudetto", "medaglia", "medal*"
        ],
        .culture: [
            "cultura", "culture", "libro", "libri", "book", "books", "romanz*", "novel", "novels", "scrittor*",
            "writer*", "poesia", "poetry", "letteratur*", "literature", "cinema", "film", "movie*", "regista",
            "attore", "attrice", "actor", "actress", "oscar", "festival", "cannes", "serie tv", "tv series",
            "netflix", "hbo", "streaming", "musica", "music", "album", "canzon*", "song", "songs", "concert*",
            "cantante", "singer", "band", "sanremo", "arte", "art", "artist*", "artista", "mostra",
            "exhibition", "museo", "musei", "museum*", "pittur*", "painting*", "teatro", "theatre", "theater",
            "opera", "storia", "history", "historian*", "storico", "filosofi*", "philosoph*", "fumett*",
            "comics", "celebrit*", "premio", "award*"
        ],
        .lifestyle: [
            "viagg*", "travel*", "vacanz*", "vacation", "holiday*", "turism*", "tourism", "hotel", "voli",
            "flight*", "destinazion*", "destination*", "itinerari*", "itinerary", "ricett*", "recipe*",
            "cucina", "cooking", "chef", "ristorant*", "restaurant*", "cibo", "food", "vino", "wine", "caffe",
            "coffee", "moda", "fashion", "stile", "style", "outfit*", "bellezza", "beauty", "skincare",
            "arredament*", "interior*", "giardin*", "garden*", "design", "relazion*", "relationship*", "dating",
            "famiglia", "family", "genitori", "parenting", "figli", "hobby", "videogioc*", "videogame*",
            "video game", "video games", "gaming", "playstation", "xbox", "nintendo", "produttivita",
            "productivity", "consigli", "tips", "lifestyle", "shopping", "offerte", "deals", "matrimonio",
            "wedding"
        ],
        .environment: [
            "ambiente", "environment", "ambiental*", "environmental*", "clima", "climate", "climatic*",
            "riscaldamento globale", "global warming", "cambiamento climatico", "climate change", "emission*",
            "emissioni", "co2", "carbonio", "carbon", "inquinament*", "pollution", "plastica", "plastic",
            "rinnovabil*", "renewable*", "solare", "solar", "eolic*", "wind power", "fotovoltaic*",
            "energia pulita", "clean energy", "transizione ecologica", "transizione energetica",
            "energy transition", "sostenibil*", "sustainab*", "biodiversit*", "ecosistem*", "ecosystem*",
            "foreste", "forest", "forests", "deforestazion*", "deforestation", "oceano", "oceani", "ocean",
            "oceans", "ghiacciai", "glacier*", "siccita", "drought", "incendi", "wildfire*", "specie",
            "species", "estinzion*", "extinction", "wildlife", "cop28", "cop29", "cop30", "greenpeace",
            "ecolog*"
        ]
    ]

    // MARK: Tag → category (user tags + TagSuggestionService vocabulary)

    static let tagCategories: [String: ArticleCategory] = [
        "news": .news, "notizie": .news, "cronaca": .news, "attualita": .news,
        "politics": .politics, "politica": .politics, "world": .politics, "esteri": .politics, "geopolitica": .politics,
        "business": .business, "startup": .business, "finance": .business, "finanza": .business,
        "marketing": .business, "economy": .business, "economia": .business, "lavoro": .business, "career": .business,
        "technology": .technology, "tecnologia": .technology, "tech": .technology, "programming": .technology,
        "javascript": .technology, "python": .technology, "web-development": .technology, "mobile": .technology,
        "ai": .technology, "machine-learning": .technology, "cybersecurity": .technology, "cloud": .technology,
        "blockchain": .technology, "data": .technology, "open-source": .technology, "gadgets": .technology,
        "science": .science, "scienza": .science, "physics": .science, "biology": .science, "space": .science,
        "research": .science, "spazio": .science,
        "medicine": .health, "health": .health, "salute": .health, "fitness": .health, "wellness": .health,
        "sports": .sports, "sport": .sports, "calcio": .sports, "football": .sports, "tennis": .sports,
        "movies": .culture, "music": .culture, "entertainment": .culture, "cinema": .culture, "libri": .culture,
        "books": .culture, "cultura": .culture, "culture": .culture, "arte": .culture, "art": .culture,
        "travel": .lifestyle, "viaggi": .lifestyle, "food": .lifestyle, "cucina": .lifestyle,
        "lifestyle": .lifestyle, "gaming": .lifestyle, "design": .lifestyle, "moda": .lifestyle,
        "environment": .environment, "ambiente": .environment, "clima": .environment, "climate": .environment
    ]

    // MARK: URL sections ("/sport/…", "tech.example.com", …)

    static let sectionCategories: [String: ArticleCategory] = [
        "cronaca": .news, "news": .news, "attualita": .news, "breaking": .news, "local": .news, "italia": .news,
        "politica": .politics, "politics": .politics, "esteri": .politics, "world": .politics, "mondo": .politics,
        "elections": .politics, "elezioni": .politics, "opinioni": .politics,
        "economia": .business, "business": .business, "finanza": .business, "finance": .business,
        "markets": .business, "mercati": .business, "money": .business, "lavoro": .business, "soldi": .business,
        "tech": .technology, "tecnologia": .technology, "technology": .technology, "hitech": .technology,
        "hi-tech": .technology, "digital": .technology, "innovazione": .technology, "gadgets": .technology,
        "scienza": .science, "science": .science, "scienze": .science, "spazio": .science, "space": .science,
        "salute": .health, "health": .health, "benessere": .health, "wellness": .health, "medicina": .health,
        "sport": .sports, "sports": .sports, "calcio": .sports, "football": .sports, "soccer": .sports,
        "tennis": .sports, "motori": .sports, "formula-1": .sports, "f1": .sports, "basket": .sports,
        "cultura": .culture, "culture": .culture, "spettacoli": .culture, "spettacolo": .culture,
        "entertainment": .culture, "arts": .culture, "books": .culture, "libri": .culture, "cinema": .culture,
        "film": .culture, "movies": .culture, "music": .culture, "musica": .culture, "tv": .culture,
        "lifestyle": .lifestyle, "viaggi": .lifestyle, "travel": .lifestyle, "food": .lifestyle,
        "cucina": .lifestyle, "moda": .lifestyle, "fashion": .lifestyle, "style": .lifestyle, "casa": .lifestyle,
        "gaming": .lifestyle, "games": .lifestyle, "videogiochi": .lifestyle, "motori-auto": .lifestyle,
        "ambiente": .environment, "environment": .environment, "climate": .environment, "clima": .environment,
        "green": .environment, "sostenibilita": .environment
    ]

    // MARK: Domains (matched on the host or any parent domain)

    /// General news outlets: a weak hint, a specific topic found in the text wins.
    static let generalNewsDomains: Set<String> = [
        "ansa.it", "repubblica.it", "corriere.it", "lastampa.it", "ilpost.it", "ilfattoquotidiano.it",
        "open.online", "tgcom24.mediaset.it", "rainews.it", "tg24.sky.it", "ilgiornale.it", "avvenire.it",
        "huffingtonpost.it", "today.it", "fanpage.it", "adnkronos.com", "agi.it", "internazionale.it",
        "ilmessaggero.it", "ilsecoloxix.it", "ilmattino.it", "lanazione.it", "ilrestodelcarlino.it",
        "bbc.com", "bbc.co.uk", "cnn.com", "nytimes.com", "theguardian.com", "reuters.com", "apnews.com",
        "washingtonpost.com", "lemonde.fr", "elpais.com", "theatlantic.com", "npr.org", "aljazeera.com"
    ]

    static let domainCategories: [String: ArticleCategory] = [
        // Sports
        "gazzetta.it": .sports, "corrieredellosport.it": .sports, "tuttosport.com": .sports,
        "sport.sky.it": .sports, "eurosport.com": .sports, "eurosport.it": .sports, "espn.com": .sports,
        "theathletic.com": .sports, "marca.com": .sports, "bleacherreport.com": .sports,
        "formula1.com": .sports, "motorsport.com": .sports, "ultimouomo.com": .sports, "calciomercato.com": .sports,
        "sportmediaset.mediaset.it": .sports, "ubitennis.com": .sports,
        // Technology
        "theverge.com": .technology, "techcrunch.com": .technology, "arstechnica.com": .technology,
        "wired.com": .technology, "wired.it": .technology, "engadget.com": .technology, "macrumors.com": .technology,
        "9to5mac.com": .technology, "9to5google.com": .technology, "hdblog.it": .technology, "dday.it": .technology,
        "punto-informatico.it": .technology, "tomshw.it": .technology, "macitynet.it": .technology,
        "smartworld.it": .technology, "github.com": .technology, "dev.to": .technology,
        "stackoverflow.com": .technology, "news.ycombinator.com": .technology, "theregister.com": .technology,
        "anandtech.com": .technology, "androidauthority.com": .technology, "hwupgrade.it": .technology,
        "openai.com": .technology, "anthropic.com": .technology, "huggingface.co": .technology,
        "swiftbysundell.com": .technology, "hackingwithswift.com": .technology, "css-tricks.com": .technology,
        // Science
        "nature.com": .science, "science.org": .science, "sciencedaily.com": .science, "nasa.gov": .science,
        "newscientist.com": .science, "quantamagazine.org": .science, "arxiv.org": .science,
        "lescienze.it": .science, "focus.it": .science, "scientificamerican.com": .science, "phys.org": .science,
        "space.com": .science, "media.inaf.it": .science, "esa.int": .science, "nationalgeographic.com": .science,
        // Business
        "bloomberg.com": .business, "ft.com": .business, "wsj.com": .business, "economist.com": .business,
        "ilsole24ore.com": .business, "milanofinanza.it": .business, "forbes.com": .business,
        "forbes.it": .business, "businessinsider.com": .business, "cnbc.com": .business, "fortune.com": .business,
        "hbr.org": .business, "startupitalia.eu": .business, "money.it": .business, "investing.com": .business,
        "morningstar.com": .business, "marketwatch.com": .business, "wallstreetitalia.com": .business,
        // Politics
        "politico.com": .politics, "politico.eu": .politics, "ispionline.it": .politics,
        "limesonline.com": .politics, "formiche.net": .politics, "thehill.com": .politics,
        "foreignaffairs.com": .politics, "foreignpolicy.com": .politics,
        // Health
        "healthline.com": .health, "webmd.com": .health, "who.int": .health, "issalute.it": .health,
        "humanitas.it": .health, "my-personaltrainer.it": .health, "statnews.com": .health,
        "medicalnewstoday.com": .health, "mayoclinic.org": .health, "fondazioneveronesi.it": .health,
        "airc.it": .health, "epicentro.iss.it": .health,
        // Culture
        "pitchfork.com": .culture, "rollingstone.com": .culture, "rollingstone.it": .culture,
        "variety.com": .culture, "hollywoodreporter.com": .culture, "illibraio.it": .culture,
        "artribune.com": .culture, "mymovies.it": .culture, "comingsoon.it": .culture, "imdb.com": .culture,
        "goodreads.com": .culture, "theparisreview.org": .culture, "lithub.com": .culture,
        "doppiozero.com": .culture, "rivistastudio.com": .culture,
        // Lifestyle
        "vogue.com": .lifestyle, "vogue.it": .lifestyle, "gq.com": .lifestyle, "gqitalia.it": .lifestyle,
        "cucchiaio.it": .lifestyle, "giallozafferano.it": .lifestyle, "lonelyplanet.com": .lifestyle,
        "cntraveler.com": .lifestyle, "dissapore.com": .lifestyle, "gamberorosso.it": .lifestyle,
        "ign.com": .lifestyle, "multiplayer.it": .lifestyle, "everyeye.it": .lifestyle,
        "eurogamer.net": .lifestyle, "eurogamer.it": .lifestyle, "polygon.com": .lifestyle,
        "kotaku.com": .lifestyle, "bonappetit.com": .lifestyle, "seriouseats.com": .lifestyle,
        "dezeen.com": .lifestyle, "archdaily.com": .lifestyle, "elledecor.com": .lifestyle,
        // Environment
        "lifegate.it": .environment, "greenpeace.org": .environment, "carbonbrief.org": .environment,
        "insideclimatenews.org": .environment, "grist.org": .environment, "rinnovabili.it": .environment,
        "greenme.it": .environment, "qualenergia.it": .environment, "climate.gov": .environment
    ]

    // MARK: Italian category definitions (semantic similarity)

    static let italianDefinitions: [ArticleCategory: String] = [
        .news: "notizie di attualità, cronaca, fatti del giorno, incidenti e notizie locali",
        .politics: "politica, governo, elezioni, partiti, leggi, diplomazia, guerre e relazioni internazionali",
        .business: "economia, aziende, mercati finanziari, borsa, lavoro, startup e risparmio",
        .technology: "tecnologia, software, smartphone, internet, intelligenza artificiale, programmazione e sicurezza informatica",
        .science: "scienza, ricerca scientifica, scoperte, fisica, biologia, spazio e astronomia",
        .health: "salute, medicina, malattie, alimentazione, salute mentale, benessere e fitness",
        .sports: "sport, calcio, tennis, ciclismo, Formula 1, Olimpiadi, partite e campionati",
        .culture: "cultura, libri, cinema, serie TV, musica, arte, teatro, storia e filosofia",
        .lifestyle: "viaggi, cucina e ricette, moda, casa, design, relazioni, hobby e videogiochi",
        .environment: "ambiente, cambiamento climatico, energia rinnovabile, inquinamento, natura e sostenibilità"
    ]
}
