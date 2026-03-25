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

target = int(input("Enter Target : "))
vector = [4,5,6]
indices = TwoSum(vector,target)
print(f"VECTOR : {indices}")