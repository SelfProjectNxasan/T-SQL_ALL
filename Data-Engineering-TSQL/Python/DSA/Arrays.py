def ContainDuplicate(nums : list[int])-> bool:
    seen = []
    ret_bool = False
    for i in range(0,len(nums)):
        if(nums[i] in(seen)):
            ret_bool = True
            break
        else:
            seen.append(nums[i])
    return ret_bool

def ValidAnagram(s : str, t:str)-> bool:
    ret_val = True
    for i in  range(0,len(s)):
        if(s[i] not in(list(t))):
            ret_val = False
            break
    return ret_val

def TwoSum(nums:list[int], target: int) -> list[int]:
    ret_vec = []
    for i in range(0,len(nums)):
        found = False
        for j in range(0,len(nums)):
            if(nums[i] + nums[j] == target and i != j):
                ret_vec.append(i)
                ret_vec.append(j)
                found = True
                break
        if(found):
            break
    return ret_vec

def groupAnagrams(strs: list[str])-> list[list[str]]:
    grp_str = []
    for i in range(0,len(strs)):
        new_group = []
        new_group.append(strs[i])
        exists = False
        for k in range(0,len(grp_str)):
            for j in range(0,len(grp_str[k])):
                if(grp_str[k][j] == strs[i]):
                    exists = True
                    break
            if(exists):
                break
        if(exists == False):
            for x in range(0,len(strs)):
                if(ValidAnagram(strs[i],strs[x]) == True and i != x):
                    if (strs[i] not in (new_group)):
                        new_group.append(strs[i])
                    new_group.append(strs[x])
            if(len(new_group) > 0):
                grp_str.append(new_group)
    return grp_str


class encoder_string:
    def __init__(self,strings : list[str] ):
        strings = self.strings

    def MaxLen(self) -> int:
        max_str = 0
        for i in range(0,len(self.strings)):
            if(len(self.strings[i]) > max_str):
                max_str = len(self.strings[i])
        return max_str+1
    
    def encode_string(self):
        str_len = self.MaxLen()
        output_str = ""
        for i in range(0,len(self.strings)):
            diff = str_len - len(self.strings[i])
            output_str = output_str + self.strings[i] 
            for k in range(diff):
                output_str += "#"
            output_str+= str(diff)
        return output_str

input_vector = [""]
print(f"GROUPED ANAGRAMS : {groupAnagrams(input_vector)}")