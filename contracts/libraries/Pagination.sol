// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

library Pagination {
    struct PaginationMetaView {
        uint256 offset;
        uint256 limit;
        uint256 count;
    }
    
    /**
     * @dev utils for constructing pagination
     * this function will compare the difference between the
     * requested limit (last = offset + limit)
     * and the actual limit (count = last ID of array)
     * if last > count, => requested limit is outside of the actual array
     * resize the pagination to the actual size
     * @return tuple(uint256, uint256)
     */
    function _paginationHandler(
        uint256 offset,
        uint256 limit,
        uint256 count
    ) internal pure returns (uint256, uint256) {
        // disable fetching with skip > count
        if (offset >= count){
            return (offset, 0);
        }

        uint256 last = offset + limit;
        uint256 _limit = limit;
        if (last > count) {
            last = count;
            _limit = count - offset;
        }

        return (last, _limit);
    }

    function _paginationResponseHandler(
        uint256 offset,
        uint256 limit,
        uint256 count
    ) internal pure returns (PaginationMetaView memory) {
        PaginationMetaView memory _paginationMeta = PaginationMetaView(offset, limit, count);

        return _paginationMeta;
    }
}
