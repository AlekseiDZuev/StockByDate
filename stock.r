brary("RMySQL")  #Библиотека для подключения к MariaDB
library("stringi") #В Rstudio Windows необходима конвертация в UTF-8
library("emayili") #Библиотека для отправки почты
library("magrittr")#Чтобы использовать оператор %>%
library("xlsx")    #Для сохранения отчёта в xlsx

#Следующие 4 строки - подсоединяюсь к MySQL и получаю список заданий 

mydb <- dbConnect(MySQL(), user = '***', password='***', dbname='***', host = '***')
dbSendQuery(mydb, "SET NAMES utf8")
rs <- dbSendQuery(mydb, "SELECT * FROM sl_task WHERE Status=0 LIMIT 1")
query<-dbFetch(rs, -1)

#Если задания есть, то меняю статус на 1 (задание взято в работу) и получаю остатки с даты 1 по дату 2

if(nrow(query)>=1){
  dbSendQuery(mydb, paste0("UPDATE sl_task SET `Status`='1' WHERE  `Time`='",query$Time,"' AND `Email`='",query$Email,"' AND `Date1`='",query$Date1,"' AND `Date2`='",query$Date2,"' AND `Status`=0 LIMIT 1"))
  rs <- dbSendQuery(mydb, paste0("SELECT s.DATE, s.article, s.stock, CASE WHEN p.podolsk IS NULL THEN 0 ELSE  p.podolsk END as podolsk FROM (SELECT DATE, article, sum(quantityNotInOrders) as stock FROM wb_stock  WHERE DATE>='",query$Date1,"' AND DATE<='",query$Date2,"'  GROUP BY DATE, article) AS s LEFT JOIN (SELECT DATE, article, sum(quantityNotInOrders) AS podolsk FROM wb_stock AS w1 WHERE DATE>='",query$Date1,"' AND DATE<='",query$Date2,"' AND warehouse='",stri_enc_toutf8('Подольск'),"' GROUP BY DATE, article) AS p ON p.article=s.article AND p.date=s.date"))
  stock = dbFetch(rs, -1)
  
#Создаю столбец с уникальными артикулами 
  
  out<-as.data.frame(table(unique(stock$article), dnn = list("article")))
  out$Freq<-NULL
  n<-2
  
#Далее циклом просиединяю столбцы Все и Подольск по датам 
  
  for(i in 1:length(unique(stock$DATE))) {
    out<-merge(out, stock[stock$DATE == unique(stock$DATE)[i],][c(2,3,4)], by='article')
    colnames(out)[n]<-paste0("Все ", unique(stock$DATE)[i])
    n<-n+1
    colnames(out)[n]<-paste0("Подольск ", unique(stock$DATE)[i])
    n<-n+1
  }

#Записываю в файл и отпавляю письмом
  
  write.xlsx2(out, "out.xlsx", row.names = FALSE)
  email <- envelope()
  class(email)
  email <- envelope(
    to = query$Email,
    from = "***hereemail**",
    subject = paste0("Отчёт по остаткам товаров по дням с ",query$Date1," по ",query$Date2),
    text = stri_enc_toutf8("Во вложении отчёт по остаткам товаров по дням")
  )
  email <- email %>% attachment(c("./out.xlsx"))
  smtp <- server(host = "smtp.gmail.com",
                 port = 465,
                 username = "***here login***",
                 password = "***here password***")
  smtp(email, verbose = TRUE)
}

