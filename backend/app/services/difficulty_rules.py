from app.schemas.quest import QuestDifficulty

DIFFICULTY_DURATION_SECONDS: dict[QuestDifficulty, int] = {
    QuestDifficulty.EASY: 25 * 60,
    QuestDifficulty.NORMAL: 45 * 60,
    QuestDifficulty.HARD: 90 * 60,
}

DIFFICULTY_EXP_REWARDS: dict[QuestDifficulty, int] = {
    QuestDifficulty.EASY: 30,
    QuestDifficulty.NORMAL: 50,
    QuestDifficulty.HARD: 100,
}


def duration_from_difficulty(difficulty: QuestDifficulty) -> int:
    return DIFFICULTY_DURATION_SECONDS[difficulty]


def exp_from_difficulty(difficulty: QuestDifficulty) -> int:
    return DIFFICULTY_EXP_REWARDS[difficulty]
