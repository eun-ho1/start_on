from datetime import UTC, datetime, timedelta, tzinfo
from zoneinfo import ZoneInfo
from zoneinfo import ZoneInfoNotFoundError

from app.repositories.base import (
    CompletedQuestRepository,
    ProfileRepository,
    QuestRepository,
    StatsRepository,
)
from app.schemas.quest import CompletedQuestRecordSchema, QuestItemResponse


class QuestServiceError(Exception):
    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code
        self.message = message


class QuestNotFoundError(QuestServiceError):
    pass


class QuestOperationError(QuestServiceError):
    pass


class QuestService:
    def __init__(
        self,
        quest_repository: QuestRepository,
        completed_quest_repository: CompletedQuestRepository,
        profile_repository: ProfileRepository,
        stats_repository: StatsRepository,
    ) -> None:
        self._quest_repository = quest_repository
        self._completed_quest_repository = completed_quest_repository
        self._profile_repository = profile_repository
        self._stats_repository = stats_repository

    def list_quests(self, user_id: str) -> list[QuestItemResponse]:
        try:
            return self._quest_repository.list_quests(user_id)
        except Exception as exc:
            raise QuestOperationError(
                "quest_list_failed",
                "Failed to load quests for the current user.",
            ) from exc

    def create_quest(self, user_id: str, quest: QuestItemResponse) -> QuestItemResponse:
        try:
            return self._quest_repository.create_quest(user_id, quest)
        except ValueError as exc:
            raise QuestOperationError(
                "quest_create_failed",
                str(exc),
            ) from exc
        except Exception as exc:
            raise QuestOperationError(
                "quest_create_failed",
                "Failed to create the quest.",
            ) from exc

    def update_quest(
        self,
        user_id: str,
        quest_id: str,
        quest: QuestItemResponse,
    ) -> QuestItemResponse:
        try:
            return self._quest_repository.update_quest(user_id, quest_id, quest)
        except ValueError as exc:
            raise QuestNotFoundError(
                "quest_not_found",
                str(exc),
            ) from exc
        except Exception as exc:
            raise QuestOperationError(
                "quest_update_failed",
                "Failed to update the quest.",
            ) from exc

    def delete_quest(self, user_id: str, quest_id: str) -> None:
        try:
            self._quest_repository.delete_quest(user_id, quest_id)
        except ValueError as exc:
            raise QuestNotFoundError(
                "quest_not_found",
                str(exc),
            ) from exc
        except Exception as exc:
            raise QuestOperationError(
                "quest_delete_failed",
                "Failed to delete the quest.",
            ) from exc

    def complete_quest(
        self,
        user_id: str,
        quest_id: str,
        *,
        elapsed_seconds: int | None = None,
        proof_image_path: str | None = None,
    ) -> CompletedQuestRecordSchema:
        try:
            quest = self._quest_repository.get_active_quest(user_id, quest_id)
        except ValueError as exc:
            raise QuestNotFoundError(
                "quest_not_found",
                str(exc),
            ) from exc
        except Exception as exc:
            raise QuestOperationError(
                "quest_complete_failed",
                "Failed to load the quest for completion.",
            ) from exc

        try:
            profile = self._profile_repository.get_profile_state(user_id)
            stats = self._stats_repository.get_stats_state(user_id)
        except ValueError as exc:
            raise QuestOperationError(
                "quest_dependency_not_found",
                str(exc),
            ) from exc
        except Exception as exc:
            raise QuestOperationError(
                "quest_complete_failed",
                "Failed to load profile or stats required for completion.",
            ) from exc

        completed_at = datetime.now(_service_timezone())
        today_key = _date_key(completed_at)
        week_key = _week_key(completed_at)
        month_key = _month_key(completed_at)
        normalized = _normalize_progress(profile, stats, today_key, week_key, month_key)
        profile = normalized["profile"]
        stats = normalized["stats"]
        recorded_elapsed_seconds = elapsed_seconds if elapsed_seconds is not None else quest.elapsed_seconds
        earned_exp = self._calculate_earned_exp(recorded_elapsed_seconds)

        next_level, next_current_exp, next_max_exp = _apply_exp(
            level=profile.level,
            current_exp=profile.current_exp,
            max_exp=profile.max_exp,
            gained_exp=earned_exp,
        )

        weekly_counts = _normalized_weekly_counts(stats.weekly_activity_counts)
        weekday_index = completed_at.weekday()  # Monday=0
        weekly_counts[weekday_index] += 1
        weekly_bars = _build_weekly_bars(weekly_counts)

        weekly_completed_count = stats.weekly_completed_count + 1
        weekly_completion_rate = _calculate_weekly_completion_rate(
            weekly_completed_count,
            stats.weekly_reward_target,
        )
        weekly_rate_delta = (
            weekly_completion_rate - stats.previous_weekly_completion_rate
        )
        diligence_stat, order_stat, intelligence_stat, health_stat = (
            _apply_category_stats(
                diligence_stat=stats.diligence_stat,
                order_stat=stats.order_stat,
                intelligence_stat=stats.intelligence_stat,
                health_stat=stats.health_stat,
                category=quest.category,
                difficulty=quest.difficulty,
            )
        )

        try:
            completed_quest_id, completed_record = self._completed_quest_repository.create_completed_quest(
                user_id=user_id,
                quest=quest,
                earned_exp=earned_exp,
                completed_at=completed_at,
                elapsed_seconds=recorded_elapsed_seconds,
                proof_image_path=proof_image_path,
            )
            self._completed_quest_repository.create_recent_activity(
                user_id=user_id,
                profile_id=profile.profile_id,
                completed_quest_id=completed_quest_id,
                activity_date=completed_at,
                subtitle=f"Completed: {quest.title}",
                exp=earned_exp,
            )
            self._stats_repository.update_stats_after_completion(
                user_id,
                completed_quest_count=stats.completed_quest_count + 1,
                earned_exp=stats.earned_exp + earned_exp,
                daily_reward_count=min(
                    stats.daily_reward_target,
                    stats.daily_reward_count + 1,
                ),
                weekly_reward_count=min(
                    stats.weekly_reward_target,
                    stats.weekly_reward_count + 1,
                ),
                monthly_reward_count=min(
                    stats.monthly_reward_target,
                    stats.monthly_reward_count + 1,
                ),
                weekly_completed_count=weekly_completed_count,
                weekly_completion_rate=weekly_completion_rate,
                previous_weekly_completion_rate=stats.previous_weekly_completion_rate,
                weekly_rate_delta=weekly_rate_delta,
                diligence_stat=diligence_stat,
                order_stat=order_stat,
                intelligence_stat=intelligence_stat,
                health_stat=health_stat,
                weekly_activity_counts=weekly_counts,
                weekly_activity_bars=weekly_bars,
            )
            self._profile_repository.update_profile_progress(
                user_id,
                level=next_level,
                current_exp=next_current_exp,
                max_exp=next_max_exp,
                user_role=_role_for_level(next_level),
                credits=profile.credits,
                daily_reset_key=profile.daily_reset_key,
                weekly_reset_key=profile.weekly_reset_key,
                monthly_reset_key=profile.monthly_reset_key,
            )
            self._quest_repository.mark_completed(user_id, quest_id)
            return completed_record
        except ValueError as exc:
            raise QuestOperationError(
                "quest_complete_failed",
                str(exc),
            ) from exc
        except Exception as exc:
            raise QuestOperationError(
                "quest_complete_failed",
                "Failed to complete the quest and update related records.",
            ) from exc

    def _calculate_earned_exp(self, elapsed_seconds: int) -> int:
        if elapsed_seconds < 10 * 60:
            return 0
        return elapsed_seconds // 60


def _apply_exp(
    *,
    level: int,
    current_exp: int,
    max_exp: int,
    gained_exp: int,
) -> tuple[int, int, int]:
    next_level = level
    next_current_exp = current_exp + gained_exp
    next_max_exp = max_exp

    while next_current_exp >= next_max_exp and next_max_exp > 0:
        next_current_exp -= next_max_exp
        next_level += 1
        next_max_exp = 500 + (next_level * 100)

    return next_level, next_current_exp, next_max_exp


def _normalized_weekly_counts(counts: list[int]) -> list[int]:
    normalized = list(counts[:7]) if counts else [0] * 7
    while len(normalized) < 7:
        normalized.append(0)
    return normalized


def _build_weekly_bars(counts: list[int]) -> list[float]:
    max_count = max(counts) if counts else 0
    if max_count <= 0:
        return [0.0] * 7
    return [count / max_count for count in counts[:7]]


def _calculate_weekly_completion_rate(
    completed_count: int,
    weekly_target: int,
) -> int:
    if weekly_target <= 0:
        return 0
    return min(100, round((completed_count / weekly_target) * 100))


def _apply_category_stats(
    *,
    diligence_stat: int,
    order_stat: int,
    intelligence_stat: int,
    health_stat: int,
    category: str,
    difficulty: str,
) -> tuple[int, int, int, int]:
    difficulty_key = difficulty.lower()
    diligence_gain = {"easy": 4, "normal": 6, "hard": 9}.get(difficulty_key, 9)
    category_gain = {"easy": 5, "normal": 8, "hard": 12}.get(difficulty_key, 12)
    normalized_category = category.lower()

    next_diligence = min(
        100,
        diligence_stat + diligence_gain + (category_gain if normalized_category == "work" else 0),
    )
    next_order = min(100, order_stat + category_gain) if normalized_category == "home" else order_stat
    next_intelligence = (
        min(100, intelligence_stat + category_gain)
        if normalized_category == "study"
        else intelligence_stat
    )
    next_health = min(100, health_stat + category_gain) if normalized_category == "life" else health_stat

    return next_diligence, next_order, next_intelligence, next_health


def _role_for_level(level: int) -> str:
    if level >= 8:
        return "Master"
    if level >= 5:
        return "Expert"
    if level >= 2:
        return "Adventurer"
    return "Beginner"


def _date_key(value: datetime) -> str:
    return value.strftime("%Y-%m-%d")


def _month_key(value: datetime) -> str:
    return value.strftime("%Y-%m")


def _week_key(value: datetime) -> str:
    start_of_week = value.replace(hour=0, minute=0, second=0, microsecond=0)
    start_of_week = start_of_week - timedelta(days=value.weekday())
    return _date_key(start_of_week)


def _service_timezone() -> tzinfo:
    try:
        return ZoneInfo("Asia/Seoul")
    except ZoneInfoNotFoundError:
        return UTC


def _normalize_progress(profile, stats, today_key: str, week_key: str, month_key: str) -> dict[str, object]:
    if profile.daily_reset_key != today_key:
        stats.daily_reward_count = 0
        profile.daily_reset_key = today_key

    if profile.weekly_reset_key != week_key:
        stats.weekly_reward_count = 0
        stats.weekly_completed_count = 0
        stats.previous_weekly_completion_rate = stats.weekly_completion_rate
        stats.weekly_completion_rate = 0
        stats.weekly_rate_delta = 0
        stats.weekly_activity_counts = [0] * 7
        stats.weekly_activity_bars = [0.0] * 7
        profile.weekly_reset_key = week_key

    if profile.monthly_reset_key != month_key:
        stats.monthly_reward_count = 0
        profile.monthly_reset_key = month_key

    if not profile.daily_reset_key:
        profile.daily_reset_key = today_key
    if not profile.weekly_reset_key:
        profile.weekly_reset_key = week_key
    if not profile.monthly_reset_key:
        profile.monthly_reset_key = month_key

    return {"profile": profile, "stats": stats}
