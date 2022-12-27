select casenumber,
translate(detaileddescription,'A BCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz`~!@#$%^&*()_-+={}|[]\:;"<,>?/',' '),
detaileddescription
from jrls.eventlog
where jrls.eventlog.category = 'Legal Judgment Amount'
  and translate(detaileddescription,'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz`~!@#$%^&*()_-+={}|[]\:;"<,>?/',' ') <>detaileddescription
