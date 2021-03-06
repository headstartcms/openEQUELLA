/*
 * Licensed to The Apereo Foundation under one or more contributor license
 * agreements. See the NOTICE file distributed with this work for additional
 * information regarding copyright ownership.
 *
 * The Apereo Foundation licenses this file to you under the Apache License,
 * Version 2.0, (the "License"); you may not use this file except in compliance
 * with the License. You may obtain a copy of the License at:
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package com.tle.core.item.serializer.where;

import com.tle.core.item.serializer.ItemSerializerState;
import com.tle.core.item.serializer.ItemSerializerWhere;
import org.hibernate.criterion.DetachedCriteria;
import org.hibernate.criterion.Order;
import org.hibernate.criterion.ProjectionList;
import org.hibernate.criterion.Projections;
import org.hibernate.criterion.Restrictions;

@SuppressWarnings("nls")
public class AllVersionsWhereClause implements ItemSerializerWhere {
  private static final String PROPERTY_VERSION = "i.version";
  public static final String ALIAS_VERSION = "version";

  private String uuid;

  public AllVersionsWhereClause(String uuid) {
    this.uuid = uuid;
  }

  @Override
  public void addWhere(ItemSerializerState state) {
    ProjectionList projections = state.getItemProjection();
    DetachedCriteria criteria = state.getItemQuery();
    criteria.add(Restrictions.eq("uuid", uuid));
    criteria.addOrder(Order.asc(PROPERTY_VERSION));
    projections.add(Projections.property(PROPERTY_VERSION), ALIAS_VERSION);
  }
}
