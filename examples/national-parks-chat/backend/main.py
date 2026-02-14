import json
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import redis
import os

app = FastAPI(title="National Parks Chat API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

REDIS_URL = os.getenv("REDIS_URL", "redis://localhost:6379/0")

try:
    redis_client = redis.from_url(REDIS_URL, decode_responses=True)
except Exception:
    redis_client = None

PARKS = [
    {
        "id": "yosemite",
        "name": "Yosemite National Park",
        "description": "Famous for its granite cliffs, waterfalls, giant sequoia groves, and biological diversity. Half Dome and El Capitan are iconic landmarks.",
        "location": "Sierra Nevada, California",
        "highlights": ["Half Dome", "El Capitan", "Yosemite Falls", "Glacier Point", "Mariposa Grove"],
        "best_time_to_visit": "May to September",
        "image_url": "https://placehold.co/600x400?text=Yosemite",
    },
    {
        "id": "sequoia",
        "name": "Sequoia National Park",
        "description": "Home to the General Sherman Tree, the largest tree on Earth by volume. Features dramatic mountain landscapes and deep canyons.",
        "location": "Southern Sierra Nevada, California",
        "highlights": ["General Sherman Tree", "Moro Rock", "Crystal Cave", "Tunnel Log", "Giant Forest"],
        "best_time_to_visit": "June to September",
        "image_url": "https://placehold.co/600x400?text=Sequoia",
    },
    {
        "id": "kings-canyon",
        "name": "Kings Canyon National Park",
        "description": "Features deep granite canyons, towering sequoias, and pristine wilderness. Kings Canyon is deeper than the Grand Canyon in places.",
        "location": "Southern Sierra Nevada, California",
        "highlights": ["Kings Canyon Scenic Byway", "General Grant Tree", "Zumwalt Meadow", "Roaring River Falls", "Cedar Grove"],
        "best_time_to_visit": "June to September",
        "image_url": "https://placehold.co/600x400?text=Kings+Canyon",
    },
    {
        "id": "joshua-tree",
        "name": "Joshua Tree National Park",
        "description": "Where the Mojave and Colorado deserts meet, famous for rugged rock formations, stark desert landscapes, and the iconic Joshua trees.",
        "location": "Southern California",
        "highlights": ["Joshua Trees", "Skull Rock", "Keys View", "Cholla Cactus Garden", "Barker Dam"],
        "best_time_to_visit": "October to May",
        "image_url": "https://placehold.co/600x400?text=Joshua+Tree",
    },
    {
        "id": "death-valley",
        "name": "Death Valley National Park",
        "description": "The hottest, driest, and lowest national park. Features stunning salt flats, sand dunes, colorful badlands, and dramatic mountain scenery.",
        "location": "Eastern California / Nevada border",
        "highlights": ["Badwater Basin", "Zabriskie Point", "Mesquite Flat Sand Dunes", "Artists Palette", "Dante's View"],
        "best_time_to_visit": "November to March",
        "image_url": "https://placehold.co/600x400?text=Death+Valley",
    },
    {
        "id": "channel-islands",
        "name": "Channel Islands National Park",
        "description": "Five remarkable islands off the southern California coast with unique plants, animals, and archaeological resources. Often called the Galapagos of North America.",
        "location": "Off the coast of Ventura, California",
        "highlights": ["Sea Caves", "Island Fox", "Whale Watching", "Snorkeling", "Painted Cave"],
        "best_time_to_visit": "Year-round (summer for water activities)",
        "image_url": "https://placehold.co/600x400?text=Channel+Islands",
    },
    {
        "id": "pinnacles",
        "name": "Pinnacles National Park",
        "description": "Known for its talus caves, striking rock spires, and diverse wildlife including the endangered California condor.",
        "location": "Central California",
        "highlights": ["Bear Gulch Cave", "Condor Gulch Trail", "High Peaks Trail", "Balconies Cave", "California Condors"],
        "best_time_to_visit": "February to May",
        "image_url": "https://placehold.co/600x400?text=Pinnacles",
    },
    {
        "id": "redwood",
        "name": "Redwood National and State Parks",
        "description": "Home to the tallest trees on Earth, including Hyperion at 380 feet. Features old-growth coast redwood forests and pristine coastline.",
        "location": "Northern California coast",
        "highlights": ["Tall Trees Grove", "Fern Canyon", "Lady Bird Johnson Grove", "Prairie Creek", "Gold Bluffs Beach"],
        "best_time_to_visit": "June to September",
        "image_url": "https://placehold.co/600x400?text=Redwood",
    },
    {
        "id": "lassen-volcanic",
        "name": "Lassen Volcanic National Park",
        "description": "Features all four types of volcanoes and remarkable hydrothermal activity including boiling pools, steaming fumaroles, and mudpots.",
        "location": "Northern California",
        "highlights": ["Lassen Peak", "Bumpass Hell", "Sulphur Works", "Manzanita Lake", "Cinder Cone"],
        "best_time_to_visit": "July to October",
        "image_url": "https://placehold.co/600x400?text=Lassen+Volcanic",
    },
    {
        "id": "point-reyes",
        "name": "Point Reyes National Seashore",
        "description": "A dramatic cape on the central California coast featuring windswept beaches, coastal cliffs, and diverse wildlife including elephant seals and tule elk.",
        "location": "Marin County, California",
        "highlights": ["Point Reyes Lighthouse", "Elephant Seal Overlook", "Tomales Point Trail", "Drakes Beach", "Tule Elk Reserve"],
        "best_time_to_visit": "September to November",
        "image_url": "https://placehold.co/600x400?text=Point+Reyes",
    },
]

PARKS_BY_ID = {p["id"]: p for p in PARKS}


@app.get("/health")
def health():
    return {"status": "healthy"}


@app.get("/api/parks")
def list_parks():
    return {"parks": PARKS}


@app.get("/api/parks/{park_id}")
def get_park(park_id: str):
    park = PARKS_BY_ID.get(park_id)
    if not park:
        return {"error": "Park not found"}, 404
    return park


class ChatRequest(BaseModel):
    message: str


@app.post("/api/chat")
def chat(req: ChatRequest):
    message = req.message.lower()

    # Check Redis cache
    cache_key = f"chat:{message.strip()}"
    if redis_client:
        try:
            cached = redis_client.get(cache_key)
            if cached:
                return {"response": cached}
        except Exception:
            pass

    response = _generate_response(message)

    if redis_client:
        try:
            redis_client.setex(cache_key, 3600, response)
        except Exception:
            pass

    return {"response": response}


def _generate_response(message: str) -> str:
    # Find matching parks
    matched = []
    for park in PARKS:
        name_lower = park["name"].lower()
        id_lower = park["id"].lower()
        if id_lower in message or any(w in message for w in name_lower.split() if len(w) > 3):
            matched.append(park)

    if any(w in message for w in ["hello", "hi", "hey", "howdy"]):
        return "Hello! I can help you learn about national parks on the west coast near California. Ask me about any park, or try questions like 'Tell me about Yosemite' or 'What are the best parks to visit in summer?'"

    if any(w in message for w in ["all parks", "list", "which parks", "how many"]):
        names = [p["name"] for p in PARKS]
        return f"We have information on {len(PARKS)} parks: {', '.join(names)}. Ask me about any of them!"

    if any(w in message for w in ["best time", "when to visit", "when should"]):
        if matched:
            lines = [f"- {p['name']}: {p['best_time_to_visit']}" for p in matched]
            return "Here are the best times to visit:\n" + "\n".join(lines)
        lines = [f"- {p['name']}: {p['best_time_to_visit']}" for p in PARKS]
        return "Best times to visit each park:\n" + "\n".join(lines)

    if any(w in message for w in ["highlight", "things to do", "attractions", "see", "activities"]):
        if matched:
            lines = [f"- {p['name']}: {', '.join(p['highlights'])}" for p in matched]
            return "Top highlights:\n" + "\n".join(lines)
        return "Ask me about highlights for a specific park! For example, 'What are the highlights of Yosemite?'"

    if any(w in message for w in ["summer", "winter", "spring", "fall"]):
        season_months = {"summer": ["june", "july", "august", "september"], "winter": ["november", "december", "january", "february", "march"], "spring": ["february", "march", "april", "may"], "fall": ["september", "october", "november"]}
        for season, months in season_months.items():
            if season in message:
                recs = [p for p in PARKS if any(m in p["best_time_to_visit"].lower() for m in months)]
                if recs:
                    names = [p["name"] for p in recs]
                    return f"Great parks to visit in {season}: {', '.join(names)}."
                return f"Most parks have limited access in {season}, but check specific park details for more info."

    if any(w in message for w in ["where", "location", "located", "find"]):
        if matched:
            lines = [f"- {p['name']}: {p['location']}" for p in matched]
            return "Park locations:\n" + "\n".join(lines)

    if matched:
        park = matched[0]
        return f"**{park['name']}** ({park['location']})\n\n{park['description']}\n\nHighlights: {', '.join(park['highlights'])}\nBest time to visit: {park['best_time_to_visit']}"

    return "I can help with information about national parks near California's west coast! Try asking about a specific park like Yosemite, Sequoia, Joshua Tree, or Death Valley. You can also ask about best times to visit, highlights, or park locations."
