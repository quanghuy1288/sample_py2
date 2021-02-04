from os import environ, path
from dotenv import load_dotenv
from environs import Env

base_dir = path.abspath(path.dirname(__file__))
load_dotenv(path.join(base_dir, ".env"))

SECRET_KEY = environ.get("SECRET_KEY")
print SECRET_KEY