class_name FloatSpin
## Floating (Shift in mid-air) whirls your legs round like a rotor, and they hit:
## anyone they reach is hurt and knocked away from you, once per float each.
## There is nothing to press: floating into or past someone is the attack.
## The host decides every hit (see Match.request_float_hit).

const DAMAGE := 15.0
const REACH := 1.3           ## metres from your hips to the edge of their body (a leg is about 0.9 m long)
const HEIGHT := 0.9          ## your hips above your feet: the middle of the rotor
const KNOCKBACK := 11.0      ## away from you
const KNOCKBACK_UP := 4.0
const SPIN_UP := 0.1         ## seconds into a float before the legs are up to speed and can hit
const REHIT := 0.5           ## the host never lets you hit the same player again sooner than this
