local ItemConfig = {
	Carrot = {
		Id = "Carrot",
		DisplayName = "Морковка",
		Description = "Временный буст к монетам.",
		BoostText = "x1.10 Coins",
		CoinMultiplier = 1.10,
		Duration = 60,
		MaxStack = 999,
	},

	Cucumber = {
		Id = "Cucumber",
		DisplayName = "Огурец",
		Description = "Временный усиленный буст к монетам.",
		BoostText = "x1.25 Coins",
		CoinMultiplier = 1.25,
		Duration = 60,
		MaxStack = 999,
	},

	Tomato = {
		Id = "Tomato",
		DisplayName = "Помидор",
		Description = "Сильный временный буст к монетам.",
		BoostText = "x1.50 Coins",
		CoinMultiplier = 1.50,
		Duration = 60,
		MaxStack = 999,
	},

	Corn = {
		Id = "Corn",
		DisplayName = "Кукуруза",
		Description = "Очень сильный временный буст к монетам.",
		BoostText = "x2.00 Coins",
		CoinMultiplier = 2.00,
		Duration = 60,
		MaxStack = 999,
	},
}

ItemConfig.Order = { "Carrot", "Cucumber", "Tomato", "Corn" }

return ItemConfig
