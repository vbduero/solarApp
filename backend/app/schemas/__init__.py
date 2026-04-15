# Schemas de Solar-Grow
from .user import UserCreate, UserLogin, UserResponse, Token
from .plant import PlantCreate, PlantUpdate, PlantResponse, PlantDetailResponse
from .sensor_data import SensorDataCreate, SensorDataResponse, SensorLatestResponse
from .task import TaskCreate, TaskUpdate, TaskResponse
from .recommendation import RecommendationResponse, AIDiagnosisResponse
