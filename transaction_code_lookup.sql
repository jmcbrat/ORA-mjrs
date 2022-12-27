select ct.transaction_code, DAILY_RATE
from CHARGE_TYPE CT,
     epic.EH_BOOKING_CUSTODY_STATUS BCS
where ct.offtrk_code = bcs.code_custody_status
  and is_active = 'yes'
  and booking_id = '0JK8IAUNW0USJZ1P'

