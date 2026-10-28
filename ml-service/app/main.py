from contextlib import asynccontextmanager
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from .config import Settings
from .controllers.prediction import router
from .models.repository import ModelRepository, ModelUnavailable
from .services.prediction import InvalidMeasurements, PredictionService


def create_app(settings: Settings | None = None):
    settings = settings or Settings.load()

    @asynccontextmanager
    async def lifespan(app):
        repository = ModelRepository(settings.model_dir)
        repository.load()
        app.state.prediction_service = PredictionService(repository)
        yield

    app = FastAPI(title="CellScope ML", version="1.2.0", lifespan=lifespan)
    app.state.settings = settings
    app.include_router(router)

    @app.exception_handler(ModelUnavailable)
    async def unavailable(request: Request, error: ModelUnavailable):
        return JSONResponse(status_code=503, content={"detail": str(error)})

    @app.exception_handler(InvalidMeasurements)
    async def invalid(request: Request, error: InvalidMeasurements):
        return JSONResponse(status_code=422, content={"detail": str(error)})

    return app


app = create_app()
