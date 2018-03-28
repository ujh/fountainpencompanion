import * as React from "react";

const Filters = ({brands, onChange}) => <div className="filters">
  <div className="form-group">
    <label>Filter by brand:</label>
    <select onChange={onChange}>
      {brands.map(b => <option key={b} value={b}>{b}</option>)}
    </select>
  </div>
</div>;

export default Filters;
