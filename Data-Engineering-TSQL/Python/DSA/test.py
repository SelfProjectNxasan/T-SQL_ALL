class StringEmcoder:
    def __init__(self,string_input:list[str],filling_char : str):
        self.string_input = string_input
        if(len(filling_char) > 0):
            self.filling_char = filling_char
        else:
            self.filling_char = "#"
        
    def GetMaxLen(self)->int:
        max_Len = 0
        for index in range(0,len(self.string_input)):
            if(len(self.string_input[index]) >= max_Len):
                max_Len = len(self.string_input[index])
        return max_Len
    
    def Encode_(self):
        index = 0
        result_string = ""
        while index < len(self.string_input):
            diff = (self.GetMaxLen()+1) - len(self.string_input[index]) 
            result_string = result_string + self.string_input[index]
            accumilate_chars = ""
            for i in range(0,diff):
                accumilate_chars = accumilate_chars + self.filling_char
            result_string = result_string+ accumilate_chars +str(diff)
            index = index + 1
        return result_string

encoder = StringEmcoder(["apple","banana","cherry","dragonfruit","elderberry"],"*")
encoded_string = encoder.Encode_()
print(f"ENCODED STRING : [{encoded_string}]")