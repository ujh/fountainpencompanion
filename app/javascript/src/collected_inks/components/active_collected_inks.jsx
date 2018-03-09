import * as React from "react";
import { connect } from "react-redux";

import InkTable from "./ink_table";

const mapStateToProps = ({ active }) => ({ ...active });

const ActiveCollectedInks = (props) => <div><InkTable {...props}/></div>;

export default connect(mapStateToProps)(ActiveCollectedInks);
