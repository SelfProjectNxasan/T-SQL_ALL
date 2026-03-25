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

nums = [1, 2, 3]
print(f"Contains Duplicates : [{ContainDuplicate(nums)}]")