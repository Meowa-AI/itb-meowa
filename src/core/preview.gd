class_name Preview
extends RefCounted
## "What happens if I do this?" — runs actions on a cloned state so the
## view can render predicted outcomes. The real state is never touched.


static func preview_attack(s: BattleState, u: BUnit, target: Vector2i) -> Array:
	var c := s.clone()
	var cu := c.unit_by_id(u.id)
	var r := Actions.do_attack(c, cu, target)
	return r["events"] if r["ok"] else []
