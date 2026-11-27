# Owner-approved monster progression policy

The production gateway can now restore each verified player's cloud monster levels before the lobby welcome is sent and pass those levels into that player's authoritative match army. This path is deliberately enabled only when the combat configuration contains a complete `monsterProgressionPolicy` block.

No default growth rates or upgrade prices are provided. Do not add guessed values to the production config.

## Required shape

Add the following object to the externally managed combat JSON:

```json
{
  "monsterProgressionPolicy": {
    "growth": {
      "runner": { "healthPerLevel": 0, "damagePerLevel": 0, "speedPerLevel": 0 },
      "tank": { "healthPerLevel": 0, "damagePerLevel": 0, "speedPerLevel": 0 },
      "stalker": { "healthPerLevel": 0, "damagePerLevel": 0, "speedPerLevel": 0 },
      "ranged": { "healthPerLevel": 0, "damagePerLevel": 0, "speedPerLevel": 0 }
    },
    "upgradeCosts": {
      "runner": { "2": 1, "3": 1, "4": 1, "5": 1, "6": 1, "7": 1, "8": 1, "9": 1, "10": 1, "11": 1, "12": 1, "13": 1, "14": 1, "15": 1, "16": 1, "17": 1, "18": 1, "19": 1, "20": 1, "21": 1, "22": 1, "23": 1, "24": 1, "25": 1, "26": 1, "27": 1, "28": 1, "29": 1, "30": 1, "31": 1, "32": 1, "33": 1, "34": 1, "35": 1, "36": 1, "37": 1, "38": 1, "39": 1, "40": 1 },
      "tank": { "2": 1, "3": 1, "4": 1, "5": 1, "6": 1, "7": 1, "8": 1, "9": 1, "10": 1, "11": 1, "12": 1, "13": 1, "14": 1, "15": 1, "16": 1, "17": 1, "18": 1, "19": 1, "20": 1, "21": 1, "22": 1, "23": 1, "24": 1, "25": 1, "26": 1, "27": 1, "28": 1, "29": 1, "30": 1, "31": 1, "32": 1, "33": 1, "34": 1, "35": 1, "36": 1, "37": 1, "38": 1, "39": 1, "40": 1 },
      "stalker": { "2": 1, "3": 1, "4": 1, "5": 1, "6": 1, "7": 1, "8": 1, "9": 1, "10": 1, "11": 1, "12": 1, "13": 1, "14": 1, "15": 1, "16": 1, "17": 1, "18": 1, "19": 1, "20": 1, "21": 1, "22": 1, "23": 1, "24": 1, "25": 1, "26": 1, "27": 1, "28": 1, "29": 1, "30": 1, "31": 1, "32": 1, "33": 1, "34": 1, "35": 1, "36": 1, "37": 1, "38": 1, "39": 1, "40": 1 },
      "ranged": { "2": 1, "3": 1, "4": 1, "5": 1, "6": 1, "7": 1, "8": 1, "9": 1, "10": 1, "11": 1, "12": 1, "13": 1, "14": 1, "15": 1, "16": 1, "17": 1, "18": 1, "19": 1, "20": 1, "21": 1, "22": 1, "23": 1, "24": 1, "25": 1, "26": 1, "27": 1, "28": 1, "29": 1, "30": 1, "31": 1, "32": 1, "33": 1, "34": 1, "35": 1, "36": 1, "37": 1, "38": 1, "39": 1, "40": 1 }
    }
  }
}
```

**The numeric values above are shape placeholders only, not approved game balance. Replace every growth and cost value before enabling this policy in production.** In particular, a zero growth value means no increase for that stat, and the example cost of 1 is not a recommended price.

## Validation rules

- All four monster types must be present in both maps.
- Each growth field must be a finite, non-negative number.
- Every target level from 2 through 40 must have a positive integer cost for every monster type.
- Missing, extra, malformed or unknown type/level keys reject the configuration.
- The server reads the player's versioned monster save only after Supabase verifies the account UUID. The loaded progression is attached to the player's internal match slot, never trusted from a client payload.
- When the policy is absent, the account screen can still show saved monster levels, but match combat remains at the configured base stats.

## Remaining work after approval

- Replace the placeholders with owner-approved values and tune from playtest telemetry.
- Connect the persistent monster-upgrade purchase command to a server-authoritative wallet/ledger transaction.
- Run the live Supabase staging and four-player match tests with real accounts.
