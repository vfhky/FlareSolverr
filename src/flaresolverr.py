import logging
import os
import sys

from fastapi import FastAPI, HTTPException
import uvicorn

import flaresolverr_service
import utils
from dtos import V1RequestBase

app = FastAPI()



@app.post("/v1")
async def controller_v1(req: V1RequestBase):
    """
    Controller v1
    """
    print(f"req={req}")
    res = flaresolverr_service.controller_v1_endpoint(req)
    if res.__error_500__:
        raise HTTPException(status_code=500, detail="Internal Server Error")

    return res


# Main entry point
if __name__ == "__main__":
    # check python version
    if sys.version_info < (3, 9):
        raise Exception("The Python version is less than 3.9, a version equal to or higher is required.")

    # validate configuration
    log_level = os.environ.get('LOG_LEVEL', 'info').upper()
    log_html = utils.get_config_log_html()
    headless = utils.get_config_headless()
    server_host = os.environ.get('HOST', '0.0.0.0')
    server_port = int(os.environ.get('PORT', 8191))

    # configure logger
    logger_format = '%(asctime)s %(levelname)-8s %(message)s'
    if log_level == 'DEBUG':
        logger_format = '%(asctime)s %(levelname)-8s ReqId %(thread)s %(message)s'
    logging.basicConfig(
        format=logger_format,
        level=log_level,
        datefmt='%Y-%m-%d %H:%M:%S',
        handlers=[
            logging.StreamHandler(sys.stdout)
        ]
    )
    
    # disable warning traces from urllib3
    logging.getLogger('urllib3').setLevel(logging.ERROR)
    logging.getLogger('selenium.webdriver.remote.remote_connection').setLevel(logging.WARNING)
    logging.getLogger('undetected_chromedriver').setLevel(logging.WARNING)

    logging.info(f'FlareSolverr {utils.get_flaresolverr_version()}')
    logging.debug('Debug log enabled')

    # Get and set current OS for global variable
    utils.get_current_platform()

    # test browser installation
    flaresolverr_service.test_browser_installation()

    webdriver_data = utils.get_webdriver_data_path()
    utils.remove_all_subfolders(webdriver_data)

    uvicorn.run(app, host=server_host, port=server_port)
