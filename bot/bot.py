import logging
from aiogram import Bot, Dispatcher, types
from aiogram.fsm.storage.memory import MemoryStorage
from aiogram.types import Message
from aiogram import Router
from aiogram.filters import CommandStart, Command
from aiogram.fsm.state import State, StatesGroup
import aiohttp
from aiogram import F
import os
from dotenv import load_dotenv

dotenv_path = os.path.join(os.path.dirname(__file__), 'key.env')
if os.path.exists(dotenv_path):
    load_dotenv(dotenv_path)

class Form(StatesGroup):
    waiting_for_server_url = State()


API_TOKEN = os.getenv("telegram_key")

server_url = None
user_server_urls = {}  # Maps user_id to server_url
logging.basicConfig(level=logging.INFO)
CCMaster = Router(name=__name__)
bot = Bot(token=API_TOKEN)
storage = MemoryStorage()
dp = Dispatcher()


@dp.message(CommandStart())
async def start(message: Message):
    await message.reply("/help пиши")


@dp.message(Command("start_mine"))
async def set_parameters(message: Message):
    parameters = message.text.split()[1:]  # Extract parameters from the command

    # Define default parameters or validate extracted ones
    if not parameters:
        parameters = ["5", "5", "3", "3"]  # Default values

    # Prepare the configuration data to be sent to the Flask server
    config_data = {
        "mainTunnelLength": parameters[0],
        "branchInterval": parameters[1],
        "branchLength": parameters[2],
        "verticalDisplacement": parameters[3],
    }

    #user_url = user_server_urls.get(message.from_user.id)
    if not server_url:
        await message.reply("You haven't set a server URL. Use /set_server_url to set it.")
        return

    flask_server_url = f"{server_url}/update-config"

    # Asynchronously send the configuration data to the Flask server
    async with aiohttp.ClientSession() as session:
        async with session.post(flask_server_url, json=config_data) as response:
            if response.status == 200:
                await message.reply("Configuration updated successfully.")
            else:
                await message.reply("Failed to update configuration. Server responded with an error.")

    await message.reply(f"Параметры установлены: {', '.join(parameters[:4])}")


@dp.message(Command("help"))
async def set_parameters(message: Message):
    await message.reply(
        f"/start_mine TunnelLength branchInterval branchLength verticalDisplacement    (если ты введёшь только /start_mine он возьмёт дефолтные значения)")


@dp.message(Command("get_command"))
async def get_minecraft_command(message: Message):
    global server_url
    if not server_url:
        await message.reply("You haven't set a server URL. Use /set_server_url to set it.")
        return

    # URL of the Flask server's get-command endpoint
    
    await command_server_url(message, "startMining")
    # Asynchronously get the command from the Flask server
    

# async def command_server_url(message, command):
#     flask_server_url = f"{server_url}/get-command"
#     async with aiohttp.ClientSession() as session:
#         async with session.post(flask_server_url, json={'action': command}) as response:
#             if response.status == 200:
#                 command_data = await response.json()
#                 # Implement any action based on the command received from the Flask server
#                 await message.reply(f"Received command: {command_data.get('action', 'No action received')}")
#             else:
#                 await message.reply("Failed to retrieve command. Server responded with an error.")

async def command_server_url(message,comand):
    flask_server_url = f"{server_url}/get-command"
    async with aiohttp.ClientSession() as session:
        async with session.post(flask_server_url, json={'action': comand}) as response:
            if response.status == 200:
                command_data = await response.json()
                # Implement any action based on the command received from the Flask server
                await message.reply(f"Received command: {command_data['message']}")
            else:
                await message.reply("Failed to retrieve command. Server responded with an error.")



@dp.message(Command("set_server_url"))
async def prompt_server_url(message: Message):
    global server_url
    if len(message.text.split()) > 1:
        server_url = message.text.split()[1]
        await message.reply("Server URL has been set successfully.")
    else:
        await message.reply("Please send me the server URL.")



@dp.message(Command("get_server_url"))
async def prompt_server_url(message: Message):
    global server_url
    if not server_url:
        await message.reply("Please /set_server_url the server URL.")
    else:
        await message.reply(f"Your {server_url}")


@dp.message(Command("shutdown"))
async def prompt_server_url(message: Message):
    global server_url
    if not server_url:
        await message.reply("Please /set_server_url the server URL.")
        
    else:
        await message.reply(f"Your {server_url}")
        await command_server_url(message,"shutdown")






async def main():
    await dp.start_polling(bot)


if __name__ == '__main__':
    import asyncio

    loop = asyncio.get_event_loop()
    loop.create_task(main())
    loop.run_forever()
