import json

# Create a valid Lottie Bodymovin animation of a sleek spinning ring with pulse
lottie_anim = {
    "v": "5.7.4",
    "fr": 60,
    "ip": 0,
    "op": 120,
    "w": 120,
    "h": 120,
    "nm": "Attendrix Biometric Loading",
    "ddd": 0,
    "assets": [],
    "layers": [
        {
            "ddd": 0,
            "ind": 1,
            "ty": 4,  # Shape layer
            "nm": "Outer Ring",
            "sr": 1,
            "ks": {
                "o": {"a": 0, "k": 100, "ix": 11},
                "r": {
                    "a": 1,
                    "k": [
                        {"i": {"x": [0.4], "y": [1]}, "o": {"x": [0.6], "y": [0]}, "t": 0, "s": [0]},
                        {"t": 120, "s": [720]},
                    ],
                    "ix": 10,
                },
                "p": {"a": 0, "k": [60, 60, 0], "ix": 2},
                "a": {"a": 0, "k": [0, 0, 0], "ix": 1},
                "s": {"a": 0, "k": [100, 100, 100], "ix": 6},
            },
            "ao": 0,
            "shapes": [
                {
                    "ty": "gr",
                    "it": [
                        {
                            "d": 1,
                            "ty": "el",
                            "s": {"a": 0, "k": [80, 80], "ix": 2},
                            "p": {"a": 0, "k": [0, 0], "ix": 3},
                            "nm": "Ellipse Path",
                            "mn": "ADBE Vector Shape - Ellipse",
                            "hd": False,
                        },
                        {
                            "ty": "st",
                            "c": {"a": 0, "k": [0.05, 0.48, 0.37, 1], "ix": 3},  # #0D7A5F primary
                            "o": {"a": 0, "k": 100, "ix": 4},
                            "w": {"a": 0, "k": 6, "ix": 5},
                            "lc": 2,  # Round cap
                            "lj": 2,  # Round join
                            "nm": "Stroke 1",
                            "mn": "ADBE Vector Graphic - Stroke",
                            "hd": False,
                        },
                        {
                            "ty": "tm",
                            "s": {
                                "a": 1,
                                "k": [
                                    {"i": {"x": [0.4], "y": [1]}, "o": {"x": [0.2], "y": [0]}, "t": 0, "s": [0]},
                                    {"i": {"x": [0.4], "y": [1]}, "o": {"x": [0.2], "y": [0]}, "t": 60, "s": [25]},
                                    {"t": 120, "s": [100]},
                                ],
                                "ix": 1,
                            },
                            "e": {
                                "a": 1,
                                "k": [
                                    {"i": {"x": [0.4], "y": [1]}, "o": {"x": [0.2], "y": [0]}, "t": 0, "s": [20]},
                                    {"i": {"x": [0.4], "y": [1]}, "o": {"x": [0.2], "y": [0]}, "t": 60, "s": [90]},
                                    {"t": 120, "s": [100]},
                                ],
                                "ix": 2,
                            },
                            "o": {"a": 0, "k": 0, "ix": 3},
                            "m": 1,
                            "nm": "Trim Paths 1",
                            "mn": "ADBE Vector Filter - Trim",
                            "hd": False,
                        },
                        {
                            "ty": "tr",
                            "p": {"a": 0, "k": [0, 0], "ix": 2},
                            "a": {"a": 0, "k": [0, 0], "ix": 1},
                            "s": {"a": 0, "k": [100, 100], "ix": 3},
                            "r": {"a": 0, "k": 0, "ix": 6},
                            "o": {"a": 0, "k": 100, "ix": 7},
                            "sk": {"a": 0, "k": 0, "ix": 4},
                            "sa": {"a": 0, "k": 0, "ix": 5},
                            "nm": "Transform",
                        },
                    ],
                    "nm": "Ring Group",
                    "np": 4,
                    "cix": 2,
                    "ix": 1,
                    "mn": "ADBE Vector Group",
                    "hd": False,
                }
            ],
            "ip": 0,
            "op": 120,
            "st": 0,
            "bm": 0,
        },
        {
            "ddd": 0,
            "ind": 2,
            "ty": 4,  # Shape layer
            "nm": "Center Pulsing Core",
            "sr": 1,
            "ks": {
                "o": {
                    "a": 1,
                    "k": [
                        {"i": {"x": [0.4], "y": [1]}, "o": {"x": [0.6], "y": [0]}, "t": 0, "s": [40]},
                        {"i": {"x": [0.4], "y": [1]}, "o": {"x": [0.6], "y": [0]}, "t": 60, "s": [100]},
                        {"t": 120, "s": [40]},
                    ],
                    "ix": 11,
                },
                "r": {"a": 0, "k": 0, "ix": 10},
                "p": {"a": 0, "k": [60, 60, 0], "ix": 2},
                "a": {"a": 0, "k": [0, 0, 0], "ix": 1},
                "s": {
                    "a": 1,
                    "k": [
                        {"i": {"x": [0.4], "y": [1]}, "o": {"x": [0.6], "y": [0]}, "t": 0, "s": [70, 70, 100]},
                        {"i": {"x": [0.4], "y": [1]}, "o": {"x": [0.6], "y": [0]}, "t": 60, "s": [115, 115, 100]},
                        {"t": 120, "s": [70, 70, 100]},
                    ],
                    "ix": 6,
                },
            },
            "ao": 0,
            "shapes": [
                {
                    "ty": "gr",
                    "it": [
                        {
                            "d": 1,
                            "ty": "el",
                            "s": {"a": 0, "k": [36, 36], "ix": 2},
                            "p": {"a": 0, "k": [0, 0], "ix": 3},
                            "nm": "Core Ellipse",
                            "mn": "ADBE Vector Shape - Ellipse",
                            "hd": False,
                        },
                        {
                            "ty": "fl",
                            "c": {"a": 0, "k": [0.12, 0.65, 0.52, 1], "ix": 4},  # Emerald teal
                            "o": {"a": 0, "k": 85, "ix": 5},
                            "r": 1,
                            "nm": "Fill 1",
                            "mn": "ADBE Vector Graphic - Fill",
                            "hd": False,
                        },
                        {
                            "ty": "tr",
                            "p": {"a": 0, "k": [0, 0], "ix": 2},
                            "a": {"a": 0, "k": [0, 0], "ix": 1},
                            "s": {"a": 0, "k": [100, 100], "ix": 3},
                            "r": {"a": 0, "k": 0, "ix": 6},
                            "o": {"a": 0, "k": 100, "ix": 7},
                            "sk": {"a": 0, "k": 0, "ix": 4},
                            "sa": {"a": 0, "k": 0, "ix": 5},
                            "nm": "Transform",
                        },
                    ],
                    "nm": "Core Group",
                    "np": 3,
                    "cix": 2,
                    "ix": 1,
                    "mn": "ADBE Vector Group",
                    "hd": False,
                }
            ],
            "ip": 0,
            "op": 120,
            "st": 0,
            "bm": 0,
        },
    ],
    "markers": [],
}

import os
os.makedirs("apps/mobile/assets/animations", exist_ok=True)
with open("apps/mobile/assets/animations/loading.json", "w") as f:
    json.dump(lottie_anim, f, indent=2)
print("Saved apps/mobile/assets/animations/loading.json successfully!")
