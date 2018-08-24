package workbench

when DEVELOPER {
	test_csv :: proc() {
		WEAPONS_CSV_TEXT ::
`weapon_name,physical_damage,fire_damage,lightning_damage,strength_scaling,dexterity_scaling,fire_scaling,lightning_scaling,enchanted
"Longsword",100,,,10,10,,,false
Fire Sword,60,60,,7,7,7,,false
"Sword of Light, The",,,150,5,5,,5,true`;

		Weapon_Record :: struct {
			weapon_name: string,
			enchanted: bool,

			physical_damage:  int,
			fire_damage:      int,
			lightning_damage: int,

			strength_scaling:  f32,
			dexterity_scaling: f32,
			fire_scaling:      f32,
			lightning_scaling: f32,
		}

		weapons := parse_csv(WEAPONS_CSV_TEXT, Weapon_Record);

		assert(weapons[0].weapon_name == "Longsword");
		assert(weapons[0].physical_damage == 100);
		assert(weapons[0].enchanted == false);

		assert(weapons[1].weapon_name == "Fire Sword");
		assert(weapons[1].fire_damage == 60);
		assert(weapons[1].fire_scaling == 7);

		assert(weapons[2].weapon_name == "Sword of Light, The");
		assert(weapons[2].physical_damage == 0);
		assert(weapons[2].enchanted == true);
	}
}
