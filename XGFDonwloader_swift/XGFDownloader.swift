//
//  XGFDownloader.swift
//  XGFDownloader
//
//  Created by 夏桂峰 on 16/6/6.
//  Copyright © 2016年 夏桂峰. All rights reserved.
//

import Foundation
/**
 *  下载完成的通知名
 */
let FGGDownloadTaskDidFinishDownloadingNotification="FGGDownloadTaskDidFinishDownloadingNotification";

/// 下载过程中回调的代码块，会多次调用
typealias ProcessHandle=(progress:Float,sizeString:String?,speedString:String?)->Void
/// 下载完成的回调
typealias CompletionHandle=()->Void
/// 下载失败的回调
typealias FailureHandle=(error:NSError)->Void


class XGFDownloader: NSObject,NSURLConnectionDataDelegate,NSURLConnectionDelegate{

    var process:ProcessHandle?
    var completion:CompletionHandle?
    var failure:FailureHandle?
    var growthSize:NSInteger?
    var lastSize:NSInteger?
    var destination_path:String?
    var urlString:String?
    var con:NSURLConnection?
    var writeHandle:NSFileHandle?
    
    
    private var timer:NSTimer?
    
    override init() {
        super.init()
        self.growthSize=0
        self.lastSize=0
        self.timer=NSTimer.scheduledTimerWithTimeInterval(0.1, target: self, selector: #selector(XGFDownloader.getGrowthSize), userInfo: nil, repeats: true)
    }
    //与计算网速相关的方法
    func getGrowthSize() {
        do{
            let dict:NSDictionary=try NSFileManager.defaultManager().attributesOfItemAtPath(self.destination_path!)
            let size=dict.objectForKey(NSFileSize)?.integerValue
            self.growthSize=size!-self.lastSize!
            self.lastSize=size
        }
        catch {
            
        }
    }
    
    /**
     断点下载
     
     - parameter urlString:  下载的地址
     - parameter toPath:     下载文件保存路径
     - parameter process:    下载过程的回调，会多次调用
     - parameter completion: 下载完成的回调
     - parameter failure:    下载失败的回调
     */
    func download(urlString:String?,toPath:String?,process:ProcessHandle?,completion:CompletionHandle?,failure:FailureHandle?){
        
        if (toPath == nil) || (urlString==nil){
            
            return;
        }
        self.destination_path=toPath
        self.urlString=urlString
        self.process=process
        self.completion=completion
        self.failure=failure
        
        let url=NSURL(string:urlString!)
        let request=NSMutableURLRequest(URL: url!)
        let exist=NSFileManager.defaultManager().fileExistsAtPath(toPath!)
        if exist {
            
            do {
                let dict:NSDictionary=try NSFileManager.defaultManager().attributesOfItemAtPath(toPath!)
                let length=dict.objectForKey(NSFileSize)?.integerValue
                let rangeString=String.init(format: "bytes=%ld-", length!)
                
                request.setValue(rangeString, forHTTPHeaderField: "Range")
            }
            catch {
                
            }
        }
        self.con=NSURLConnection(request: request, delegate: self)
    }
    //MARK:便捷方法
    class func downloader() -> XGFDownloader {
        
        let downloader=XGFDownloader();
        return downloader;
    }
    /**
     获取上一次的下载进度
     
     - parameter url: 下载链接
     
     - returns: 下载进度
     */
    class func lastProgress(url:String?)->Float{
        
        if(url==nil){
            return 0.0;
        }
        return NSUserDefaults.standardUserDefaults().floatForKey(String(format: "%@progress",url!))
    }
    //MARK:Cancel
    func cancel(){
        self.con?.cancel()
        self.con=nil
        if (self.timer != nil){
            self.timer?.invalidate()
            self.timer=nil
        }
    }
    
    /**
     获取文件大小及总大小组成的字符串
     
     - parameter url: 下载链接
     
     - returns: 大小字符串 如：12.10M/100.60M
     */
    class func filesSize(url:String?)->String{
        
        if(url==nil){
            return "0.00K/0.00K"
        }
        let lenthKey=String(format: "%@totalLength",url!)
        let totalLength=NSUserDefaults.standardUserDefaults().integerForKey(lenthKey)
        if(totalLength==0){
            return "0.00K/0.00K"
        }
        let progressKey=String(format: "%@progress",url!)
        let downloadProgress=NSUserDefaults.standardUserDefaults().floatForKey(progressKey)
        let currentLength=Int(Float(totalLength) * downloadProgress)
        let currentSize=self.convertSize(currentLength)
        let totalSize=self.convertSize(totalLength)
        return String(format: "%@/%@",currentSize,totalSize)
    }
    
    //MARK:转换
    class func convertSize(length:NSInteger?)->String{
        
        if length<1024 {
            return String(format: "%ldB",length!)
        }
        else if length>=1024&&length<1024*1024 {
            return String(format: "%.0fK",Float(length!/1024))
        }
        else if length>=1024*1024&&length<1024*1024*1024 {
            
            return String(format: "%.1fM",Float(length!/(1024*1024)))
        }
        else{
            return String(format: "%.1fG",Float(length!/(1024*1024*1024)))
        }
    }

    //MARK:NSURLConnection
    func connection(connection: NSURLConnection, didFailWithError error: NSError) {
        if (self.failure != nil){
            self.failure!(error: error)
        }
    }
    func connection(connection: NSURLConnection, didReceiveResponse response: NSURLResponse) {
        
        let lenthKey=String(format: "%@totalLength",self.urlString!)
        let totalLength=NSUserDefaults.standardUserDefaults().integerForKey(lenthKey)
        if(totalLength==0){
            let expectLength=Int(response.expectedContentLength);
            NSUserDefaults.standardUserDefaults().setInteger(expectLength, forKey: lenthKey)
            NSUserDefaults.standardUserDefaults().synchronize()
        }
        let exist=NSFileManager.defaultManager().fileExistsAtPath(self.destination_path!)
        if !exist{
            NSFileManager.defaultManager().createFileAtPath(self.destination_path!, contents: nil, attributes: nil)
        }
        self.writeHandle=NSFileHandle.init(forWritingAtPath: self.destination_path!)
        print(self.destination_path)
    }
    func connection(connection: NSURLConnection, didReceiveData data: NSData){
        
        self.writeHandle?.seekToEndOfFile()
        self.writeHandle?.writeData(data)
        do{
            let dict:NSDictionary=try NSFileManager.defaultManager().attributesOfItemAtPath(self.destination_path!)
            let length=dict.objectForKey(NSFileSize)?.integerValue
            let lenthKey=String(format: "%@totalLength",self.urlString!)
            let totalLength=NSUserDefaults.standardUserDefaults().integerForKey(lenthKey)
            let downloadProgress=Float(length!)/(Float(totalLength))
            
            let progressKey=String(format: "%@progress",self.urlString!)
            NSUserDefaults.standardUserDefaults().setFloat(downloadProgress, forKey: progressKey)
            NSUserDefaults.standardUserDefaults().synchronize()
            
            let sizeString=XGFDownloader.filesSize(self.urlString)
            //print(sizeString)
            var speedString="0.0Kb/s"
            let growthString=XGFDownloader.convertSize(self.growthSize!*Int(1.0/0.1))
            speedString=String(format: "%@/s",growthString)
            //print(speedString)
            if self.process != nil {
                self.process!(progress: downloadProgress,sizeString: sizeString,speedString: speedString)
            }
        }
        catch {
            
        }

    }
    func connectionDidFinishLoading(connection: NSURLConnection) {
        
        let dict:Dictionary<String,String>=["urlString":self.urlString!]
        NSNotificationCenter.defaultCenter().postNotificationName(FGGDownloadTaskDidFinishDownloadingNotification, object: nil,userInfo:dict)
        self.cancel()
        if self.completion != nil {
            self.completion!()
        }
    }
}

