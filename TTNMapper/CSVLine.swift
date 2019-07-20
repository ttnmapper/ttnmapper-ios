//
//  CSVLine.swift
//  TTNMapper
//
//  Created by Timothy Sealy on 09/08/16.
//  Copyright © 2016 Timothy Sealy. All rights reserved.
//

import Foundation

class CSVLine {
    fileprivate var values : [String]
    
    init(line: String){
        values = line.components(separatedBy: ",")
    }
    
    func safeGetValue(_ index: Int) -> String? {
        if values.indices.contains(index) {
            return values[index]
        }
        return nil
    }
}
