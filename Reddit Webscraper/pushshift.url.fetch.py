from pushshift_py import PushshiftAPI
import datetime
import pandas
import os



def FetchData(monthInt, daysInMonth):

    api = PushshiftAPI()
    data = []
    secondsInHour = 3600
    secondsInDay = secondsInHour * 24    

    for day in range(1, daysInMonth):
        startEpoch = int(datetime.datetime(2020, monthInt, day).timestamp())
        
        for hour in range(secondsInHour, secondsInDay, 3600):
            endEpoch = startEpoch + hour
        
            data.append(list(api.search_submissions(after = startEpoch, before = endEpoch, subreddit = "stopdrinking", filter = ["url" ], limit = 100)))

            startEpoch = endEpoch
            
        day += 1
        print(day)
    return data

def UnnestURLs(dataframe):
    
    urlList = []
    
    for row in range(0, dataframe.shape[0]): #Returns rows. Shape index 0 shows the number of rows
        print("Row: " + str(row))
        
        for col in range(0, dataframe.shape[1]): #Returns columns
            
            try:
                url = dataframe[col][row][1]
            except: #Catch every NoneType error, just continue on
                continue
            
            urlList.append(url)
            
    return pandas.DataFrame(urlList)

def main():
    marchDF   = pandas.DataFrame(FetchData(3, 31))
    aprilDF   = pandas.DataFrame(FetchData(4, 30))
    mayDF   = pandas.DataFrame(FetchData(5, 31))
    juneDF   = pandas.DataFrame(FetchData(6, 30))
    julyDF   = pandas.DataFrame(FetchData(7, 31))
    augustDF   = pandas.DataFrame(FetchData(8, 31))
    septemberDF   = pandas.DataFrame(FetchData(9, 19))
    
    marchUrlDF = UnnestURLs(marchDF)
    aprilUrlDF = UnnestURLs(aprilDF)
    mayUrlDF = UnnestURLs(mayDF)
    juneUrlDF = UnnestURLs(juneDF)
    julyUrlDF = UnnestURLs(julyDF)
    augustUrlDF = UnnestURLs(augustDF)
    septemberUrlDF = UnnestURLs(septemberDF)
    
    marchUrlDF.to_csv("reddit.url.data.march.2020.csv", index = False)
    aprilUrlDF.to_csv("reddit.url.data.april.2020.csv", index = False)
    mayUrlDF.to_csv("reddit.url.data.may.2020.csv", index = False)
    juneUrlDF.to_csv("reddit.url.data.june.2020.csv", index = False)
    julyUrlDF.to_csv("reddit.url.data.july.2020.csv", index = False)
    augustUrlDF.to_csv("reddit.url.data.august.2020.csv", index = False)
    septemberUrlDF.to_csv("reddit.url.data.september.2020.csv", index = False)
    

    
main()


