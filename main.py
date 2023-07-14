
import os
import time
import logging
import pandas as pd

from glob import glob
from pathlib import Path
from typing import Literal

from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.firefox.options import Options
from selenium.webdriver.firefox.service import Service
from selenium.webdriver.support.ui import Select, WebDriverWait
from selenium.webdriver.common.action_chains import ActionChains
from selenium.webdriver.support import expected_conditions as EC


SENAVE_URL = 'http://secure.senave.gov.py:8443/registros/servlet/com.consultaregistros2.prod_agro2'

_PROD_TYPES = Literal["P", "F", "M"]


def create_and_setup_webdriver():

    # Set Firefox options to enable file downloads
    firefox_options = Options()
    firefox_options.add_argument("--headless")
    firefox_options.set_preference('browser.download.folderList', 2)
    firefox_options.set_preference('browser.download.dir', os.getcwd())
    firefox_options.set_preference('browser.helperApps.neverAsk.saveToDisk', 'application/octet-stream')

    # Create a new instance of the browser driver
    service = Service(log_path='/tmp/geckodriver.log')
    driver = webdriver.Firefox(options=firefox_options, service=service)

    # Return new webdriver
    return driver


def download_reg_senave(prod_type: _PROD_TYPES) -> Path:

    # Create a new instance of the Chrome driver
    driver = create_and_setup_webdriver()

    # Open the URL in the browser
    driver.get(SENAVE_URL)

    # Find the selector element and select by value
    # select = Select(driver.find_element(By.ID, 'vPRO_TIPO'))
    select = Select(WebDriverWait(driver, 10).until(
        EC.element_to_be_clickable((By.ID, "vPRO_TIPO"))))
    select.select_by_value(prod_type)

    # Find the download button element
    # download_button = driver.find_element(By.NAME, 'BUTTON2')
    download_button = WebDriverWait(driver, 10).until(
        EC.element_to_be_clickable((By.NAME, "BUTTON2")))

    # Click the download button
    action_chain = ActionChains(driver)
    action_chain.move_to_element(download_button).click().perform()

    # Wait until the file is downloaded
    timeout = 120  # Maximum time to wait for the file to be downloaded (in seconds)
    start_time = time.time()
    while not glob(f'{os.getcwd()}/excel_prod-*.xlsx'):
        if time.time() - start_time > timeout:
            print('Timeout: File download took too long.')
            break
        time.sleep(1)

    # Close the browser
    driver.quit()

    # There must be only one .xlsx file
    assert len(glob(f'{os.getcwd()}/excel_prod-*.xlsx')) == 1

    # Return file name
    return Path(glob(f'{os.getcwd()}/excel_prod-*.xlsx')[0])


def convert_xlsx_to_csv(reg_senave_xlsx: Path, reg_senave_csv: Path, remove_xlsx: bool = True):

    import warnings
    warnings.filterwarnings('ignore', category=UserWarning, module='openpyxl')

    # Convert xlsx to csv
    pd.read_excel(reg_senave_xlsx, engine='openpyxl').to_csv(reg_senave_csv, index=False)

    # Remove downloaded file
    if remove_xlsx:
        reg_senave_xlsx.unlink()


if __name__ == '__main__':

    # Conf logging
    logging.basicConfig(format='%(asctime)s -- %(levelname)4s -- %(message)s',
                        datefmt='%Y/%m/%d %I:%M:%S %p', level=logging.INFO)

    logging.info('Downloading "fitosanitarios" from SENAVE')
    # Download P type (fitosanitarios)
    reg_fito = download_reg_senave('P')
    # Convert xlsx to csv
    convert_xlsx_to_csv(reg_fito, Path(f'{os.getcwd()}/fitosanitarios.csv'))

    logging.info('Downloading "fertilizantes" from SENAVE')
    # Download F type (fertilizantes)
    reg_ferti = download_reg_senave('F')
    # Convert xlsx to csv
    convert_xlsx_to_csv(reg_ferti, Path(f'{os.getcwd()}/fertilizantes.csv'))
