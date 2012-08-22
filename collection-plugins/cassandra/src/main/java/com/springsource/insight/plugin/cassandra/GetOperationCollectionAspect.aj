/**
 * Copyright 2009-2011 the original author or authors.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *         http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package com.springsource.insight.plugin.cassandra;


import org.aspectj.lang.JoinPoint;
import org.apache.cassandra.thrift.Cassandra;
import org.apache.cassandra.thrift.ColumnParent;
import org.apache.cassandra.thrift.ColumnPath;
import org.apache.cassandra.thrift.ConsistencyLevel;
import org.apache.cassandra.thrift.IndexClause;
import org.apache.cassandra.thrift.IndexExpression;
import org.apache.cassandra.thrift.KeyRange;
import org.apache.cassandra.thrift.SlicePredicate;
import org.apache.cassandra.thrift.SliceRange;

import com.springsource.insight.collection.AbstractOperationCollectionAspect;
import com.springsource.insight.intercept.operation.Operation;
import com.springsource.insight.intercept.operation.OperationList;
import com.springsource.insight.intercept.operation.OperationMap;

import java.nio.ByteBuffer;
import java.util.List;

/**
 * Collection operation for CassandraDB CQL queries
 */
public privileged aspect GetOperationCollectionAspect extends AbstractOperationCollectionAspect {
    public GetOperationCollectionAspect() {
        super();
    }

    public pointcut collectionPoint() : execution(public * org.apache.cassandra.thrift.Cassandra.Client.get*(..)) ||
    									execution(public * org.apache.cassandra.thrift.Cassandra.Client.multiget_*(..));

	@Override
    protected Operation createOperation(JoinPoint jp) {
    	String method=jp.getSignature().getName(); //method name
    	Object[] args = jp.getArgs();
    	
		Operation operation = OperationUtils.createOperation(OperationCollectionTypes.GET_TYPE, method, getSourceCodeLocation(jp)); 
		// get transport info
		OperationUtils.putTransportInfo(operation, ((Cassandra.Client)jp.getTarget()).getInputProtocol());

		operation.putAnyNonEmpty("consistLevel", (args[args.length-1]!=null)?((ConsistencyLevel)args[args.length-1]).name():null);
		for (int i=0; i<args.length-1; i++) {
			if (args[i] instanceof ByteBuffer) {
				if (i==0) {
					operation.put("key", OperationUtils.getText((ByteBuffer)args[i]));
				}
				else {
					operation.putAnyNonEmpty("startColumn", OperationUtils.getString((ByteBuffer)args[i]));
				}
			}
			else
			if (args[i] instanceof List) {
				if (args[i]!=null) {
					OperationList keys=operation.createList("keys");
					for(ByteBuffer key: (List<ByteBuffer>)args[i]) {
						keys.add(OperationUtils.getString(key));
					}
				}
			}
			else
			if (args[i] instanceof ColumnParent) {
				ColumnParent colParent=(ColumnParent)args[i];
				if (colParent!=null) {
					operation.put("columnFamily", OperationUtils.getText(colParent.getColumn_family()));
					operation.putAnyNonEmpty("superColumn", OperationUtils.getString(colParent.getSuper_column()));
				}
			}
			else
			if (args[i] instanceof SlicePredicate) {
				SlicePredicate pred=(SlicePredicate)args[i];
				if (pred!=null) {
					if (pred.getColumn_names()!=null) {
						OperationList cols=operation.createList("columns");
						for(ByteBuffer col: pred.getColumn_names()) {
							cols.add(OperationUtils.getString(col));
						}
					}
					
					SliceRange range=pred.getSlice_range();
					if (range!=null) {
						OperationMap rangeMap=operation.createMap("range");
						rangeMap.put("start", OperationUtils.getText(range.getStart()));
						rangeMap.put("end", OperationUtils.getText(range.getFinish()));
						rangeMap.put("count", range.getCount());
						rangeMap.put("reversed", range.isReversed());
					}
				}
			}
			else
			if (args[i] instanceof KeyRange) {
				KeyRange range=(KeyRange)args[i];
				if (range!=null) {
					OperationMap rangeMap=operation.createMap("range");
					rangeMap.put("count", range.getCount());
					rangeMap.put("startKey", OperationUtils.getString(range.getStart_key()));
					rangeMap.putAnyNonEmpty("startToken", range.getStart_token());
					rangeMap.put("endKey", OperationUtils.getString(range.getEnd_key()));
					rangeMap.putAnyNonEmpty("endToken", range.getEnd_token());
					
					if (range.getRow_filter()!=null) {
						OperationList filter=operation.createList("rowFilter");
						for(IndexExpression exp: range.getRow_filter()) {
							filter.add(OperationUtils.getText(exp.getColumn_name())+" "+exp.getOp().name()+" "+OperationUtils.getAnyData(exp.getValue()));
						}
					}
				}
			}
			else
			if (args[i] instanceof  ColumnPath) {
				ColumnPath colPath=(ColumnPath)args[i];
				if (colPath!=null) {
					operation.put("columnFamily", OperationUtils.getText(colPath.getColumn_family()));
					operation.putAnyNonEmpty("superColumn", OperationUtils.getString(colPath.getSuper_column()));
					operation.putAnyNonEmpty("colName", OperationUtils.getString(colPath.getColumn()));
				}
			}
			else
			if (args[i] instanceof IndexClause) {
				IndexClause indCls=(IndexClause)args[i];
				if (indCls!=null) {
					operation.put("startKey", OperationUtils.getText(indCls.getStart_key()));
					operation.put("count", indCls.getCount());
					List<IndexExpression> exps=indCls.getExpressions();
					if (exps!=null && exps.size()>0) {
						OperationList listExp=operation.createList("indexExp");
						for(IndexExpression exp: exps) {
							listExp.add(OperationUtils.getText(exp.getColumn_name())+" "+exp.getOp().name()+" "+OperationUtils.getAnyData(exp.getValue()));
						}
					}
				}
			}
			else
			if (args[i] instanceof String) {
				operation.put("columnFamily", OperationUtils.getText((String)args[i]));
			}
		}
		
		return operation;
    }
    
	@Override
    public String getPluginName() {
		return CassandraPluginRuntimeDescriptor.PLUGIN_NAME;
	}
}
