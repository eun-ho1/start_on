from fastapi import APIRouter

from app.api.routes.auth import router as auth_router
from app.api.routes.ai import router as ai_router
from app.api.routes.debug import router as debug_router
from app.api.routes.dungeons import router as dungeons_router
from app.api.routes.health import router as health_router
from app.api.routes.integrations_notion import router as integrations_notion_router
from app.api.routes.profile import router as profile_router
from app.api.routes.quests import router as quests_router
from app.api.routes.stats import router as stats_router

router = APIRouter()
router.include_router(auth_router, tags=["auth"])
router.include_router(health_router, tags=["health"])
router.include_router(debug_router, tags=["debug"])
router.include_router(ai_router, prefix="/ai", tags=["ai", "quests"])
router.include_router(dungeons_router, tags=["dungeons"])
router.include_router(quests_router, prefix="/quests", tags=["quests"])
router.include_router(profile_router, tags=["profile"])
router.include_router(stats_router, tags=["stats"])
router.include_router(
    integrations_notion_router,
    tags=["integrations", "notion"],
)
